"""
Custom exception handler for better error logging
"""
import logging
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)

def custom_exception_handler(exc, context):
    """
    Custom exception handler that logs 500 errors with full context.
    Helps identify what went wrong with registration or other endpoints.
    """
    # Call REST framework's default exception handler first
    response = exception_handler(exc, context)
    
    # Log the exception with full context
    if response is None:
        # This is a 500 error (unhandled exception)
        logger.error(
            f"Unhandled exception in {context['view'].__class__.__name__}",
            exc_info=exc,
            extra={
                'request': context['request'],
                'view': context['view'].__class__.__name__,
                'method': context['request'].method,
                'path': context['request'].path,
                'user': context['request'].user,
            }
        )
    
    return response
