"""
Custom exception handler for better error logging and safe client responses.
"""
import logging

from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Return 4xx for known validation failures; log unhandled exceptions as 500.
    """
    if isinstance(exc, DjangoValidationError):
        if hasattr(exc, "message_dict"):
            detail = exc.message_dict
        elif hasattr(exc, "messages"):
            detail = exc.messages
        else:
            detail = str(exc)
        return Response({"detail": detail}, status=status.HTTP_400_BAD_REQUEST)

    response = exception_handler(exc, context)

    if response is None:
        logger.error(
            "Unhandled exception in %s",
            context["view"].__class__.__name__,
            exc_info=exc,
            extra={
                "view": context["view"].__class__.__name__,
                "method": context["request"].method,
                "path": context["request"].path,
            },
        )

    return response
