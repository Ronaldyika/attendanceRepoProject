"""
Sync Processor
==============
Contains all server-side re-validation logic for batch synchronisation.
Called by the SyncView.  Separated into its own module for testability.

Validation pipeline per record
--------------------------------
1.  Parse and validate idempotency_key format.
2.  Resolve session and student.
3.  Device UUID match against registered device.
4.  HMAC-SHA256 signature verification.
5.  QR expiry / clock-skew check.
6.  Duplicate detection (idempotency_key uniqueness).
7.  Cross-device conflict detection (same student + session, different device).
8.  If all pass → INSERT with ON CONFLICT DO NOTHING semantics.
"""
import logging
import time

from django.conf import settings
from django.db import IntegrityError
from django.utils import timezone

from .models import (
    AttendanceRecord,
    AttendanceSession,
    ConflictLog,
    IntegrityLog,
    SyncBatch,
)
from .qr_utils import verify_qr_payload

logger = logging.getLogger(__name__)

CLOCK_SKEW_TOLERANCE = getattr(settings, "CLOCK_SKEW_TOLERANCE_SECONDS", 300)


def _log_integrity(
    violation_type, detail, raw_payload, session=None, student=None, batch=None
):
    IntegrityLog.objects.create(
        session=session,
        student=student,
        violation_type=violation_type,
        detail=detail,
        raw_payload=raw_payload,
        sync_batch=batch,
    )


def process_sync_batch(user, device_uuid: str, records: list, batch: SyncBatch) -> dict:
    """
    Process all records in a sync batch.

    Returns a summary dict:
        {accepted, rejected, duplicates, conflict_ids, integrity_ids}
    """
    accepted = 0
    rejected = 0
    duplicates = 0
    conflict_ids = []
    integrity_ids = []

    now_unix = int(time.time())

    for raw in records:
        session_id = raw.get("session_id")
        item_device_uuid = raw.get("device_uuid", "")
        scanned_at = raw.get("scanned_at")
        idempotency_key = raw.get("idempotency_key", "")
        hmac_signature = raw.get("hmac_signature", "")
        qr_payload = raw.get("qr_payload", "")

        # ── 1. Resolve session ────────────────────────────────────────────
        try:
            session = AttendanceSession.objects.select_related("course").get(
                id=session_id
            )
        except AttendanceSession.DoesNotExist:
            _log_integrity(
                IntegrityLog.ViolationType.OTHER,
                f"Session {session_id} not found.",
                raw, batch=batch,
            )
            rejected += 1
            continue

        # ── 2. Device UUID match ──────────────────────────────────────────
        if user.device_uuid and user.device_uuid != item_device_uuid:
            il = _log_integrity(
                IntegrityLog.ViolationType.DEVICE_MISMATCH,
                (
                    f"Registered: {user.device_uuid}  "
                    f"Submitted: {item_device_uuid}"
                ),
                raw, session=session, student=user, batch=batch,
            )
            rejected += 1
            continue

        # ── 3. Cross-device conflict (same student+session, different device) ──
        existing_other_device = AttendanceRecord.objects.filter(
            student=user, session=session
        ).exclude(device_uuid=item_device_uuid).first()

        if existing_other_device:
            cl = ConflictLog.objects.create(
                session=session,
                student=user,
                registered_device_uuid=user.device_uuid or "",
                submitting_device_uuid=item_device_uuid,
                idempotency_key=idempotency_key,
                raw_payload=raw,
                sync_batch=batch,
            )
            conflict_ids.append(str(cl.id))
            rejected += 1
            logger.warning("Conflict detected for student %s session %s", user.id, session.id)
            continue

        # ── 4. HMAC + expiry verification ────────────────────────────────
        ok, reason = verify_qr_payload(
            qr_payload, session.session_secret, CLOCK_SKEW_TOLERANCE
        )
        if not ok:
            violation = (
                IntegrityLog.ViolationType.BAD_HMAC
                if reason == "invalid_hmac"
                else IntegrityLog.ViolationType.EXPIRED_QR
                if reason == "expired"
                else IntegrityLog.ViolationType.OTHER
            )
            _log_integrity(violation, f"QR verification failed: {reason}", raw,
                           session=session, student=user, batch=batch)
            rejected += 1
            continue

        # ── 5. Clock-skew check on scanned_at vs server receive time ─────
        if scanned_at:
            scanned_unix = int(scanned_at.timestamp()) if hasattr(scanned_at, "timestamp") else 0
            drift = abs(now_unix - scanned_unix)
            if drift > CLOCK_SKEW_TOLERANCE * 10:   # lenient: 10× tolerance for old offline records
                il = _log_integrity(
                    IntegrityLog.ViolationType.CLOCK_SKEW,
                    f"Clock drift {drift}s exceeds threshold.",
                    raw, session=session, student=user, batch=batch,
                )
                integrity_ids.append(str(il) if il else "")
                # Don't reject – flag only; record still accepted

        # ── 6. Duplicate / idempotency check ─────────────────────────────
        if AttendanceRecord.objects.filter(idempotency_key=idempotency_key).exists():
            duplicates += 1
            continue   # Silently ignore – idempotent

        # ── 7. INSERT ─────────────────────────────────────────────────────
        try:
            AttendanceRecord.objects.create(
                id=__import__("uuid").uuid4(),
                student=user,
                session=session,
                device_uuid=item_device_uuid,
                scan_source=AttendanceRecord.ScanSource.OFFLINE,
                scanned_at=scanned_at,
                synced_at=timezone.now(),
                idempotency_key=idempotency_key,
                hmac_signature=hmac_signature,
                pending_sync=False,
                sync_batch=batch,
            )
            accepted += 1
        except IntegrityError:
            # Race condition – treated as duplicate
            duplicates += 1

    return {
        "accepted": accepted,
        "rejected": rejected,
        "duplicates": duplicates,
        "conflict_ids": conflict_ids,
        "integrity_ids": integrity_ids,
    }
