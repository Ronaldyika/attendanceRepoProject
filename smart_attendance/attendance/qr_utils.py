"""
QR Code Utilities
=================
Implements the HMAC-SHA256 QR payload generation and verification
described in the research proposal (Section 3.3 & 3.5).

QR Payload Format (pipe-delimited, signed with HMAC-SHA256):
    <session_id>|<course_code>|<expiry_unix>|<hmac_hex>

The HMAC key is the session_secret stored only on the server and
transmitted to the Lecturer device at session-creation time.
Students never receive the secret; they receive only the signed
QR payload — ensuring they cannot forge a valid code.
"""
import hashlib
import hmac
import secrets
import time


def generate_session_secret() -> str:
    """Generate a cryptographically secure 64-byte hex session secret."""
    return secrets.token_hex(64)


def build_payload_base(session_id: str, course_code: str, expiry_unix: int) -> str:
    """Construct the canonical string that is signed."""
    return f"{session_id}|{course_code}|{expiry_unix}"


def compute_hmac(payload_base: str, secret: str) -> str:
    """Return HMAC-SHA256 hex digest of `payload_base` using `secret`."""
    return hmac.new(
        secret.encode("utf-8"),
        payload_base.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def generate_qr_payload(
    session_id: str,
    course_code: str,
    secret: str,
    validity_seconds: int = 900,
) -> dict:
    """
    Build a complete, signed QR payload dict.

    Returns
    -------
    {
        "payload": "<base>|<hmac>",   # The string encoded into the QR image
        "expiry_unix": int,
        "hmac": str,
    }
    """
    expiry_unix = int(time.time()) + validity_seconds
    payload_base = build_payload_base(session_id, course_code, expiry_unix)
    signature = compute_hmac(payload_base, secret)
    return {
        "payload": f"{payload_base}|{signature}",
        "expiry_unix": expiry_unix,
        "hmac": signature,
    }


def parse_qr_payload(raw_payload: str) -> dict | None:
    """
    Parse a raw QR string into components.

    Returns None if the format is invalid.
    """
    parts = raw_payload.split("|")
    if len(parts) != 4:
        return None
    session_id, course_code, expiry_unix_str, signature = parts
    try:
        expiry_unix = int(expiry_unix_str)
    except ValueError:
        return None
    return {
        "session_id": session_id,
        "course_code": course_code,
        "expiry_unix": expiry_unix,
        "signature": signature,
    }


def verify_qr_payload(
    raw_payload: str,
    secret: str,
    clock_skew_tolerance: int = 300,
) -> tuple[bool, str]:
    """
    Fully verify a QR payload.

    Checks
    ------
    1. Correct format (4 pipe-delimited parts).
    2. HMAC-SHA256 signature is valid.
    3. Payload has not expired (with clock_skew_tolerance).

    Returns
    -------
    (True, "ok") on success or (False, "<reason>") on failure.
    """
    parsed = parse_qr_payload(raw_payload)
    if parsed is None:
        return False, "invalid_format"

    payload_base = build_payload_base(
        parsed["session_id"],
        parsed["course_code"],
        parsed["expiry_unix"],
    )
    expected_hmac = compute_hmac(payload_base, secret)

    if not hmac.compare_digest(expected_hmac, parsed["signature"]):
        return False, "invalid_hmac"

    now = int(time.time())
    if now > parsed["expiry_unix"] + clock_skew_tolerance:
        return False, "expired"

    return True, "ok"
