import 'package:dio/dio.dart';
import '../utils/string_utils.dart';

/// Unwraps Django paginated `{ count, results }` or a plain JSON array.
List<dynamic> extractPaginatedList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['results'] is List) {
    return data['results'] as List;
  }
  return [];
}

Map<String, dynamic>? asStringMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    return data.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

/// Parses DRF validation errors (top-level field keys) and generic `detail`.
String parseApiError(
  dynamic e, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    final map = asStringMap(body);
    if (map != null) {
      final parsed = _formatErrorMap(map);
      if (parsed != null) return parsed;
    }

    if (body is String && body.trim().isNotEmpty) {
      if (body.contains('<!doctype html>') || body.contains('Server Error')) {
        return _serverErrorMessage(status);
      }
      return body.truncate(200);
    }
    if (status == 403) return 'You do not have permission for this action.';
    if (status == 404) return 'Resource not found.';
    if (status == 409) {
      return 'Email already registered or registration number in use.';
    }
    if (status != null && status >= 500) {
      return _serverErrorMessage(status);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timeout. Check your internet connection.';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server timeout. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Network error. Check your connection.';
    }

    if (e.message != null && e.message!.isNotEmpty) {
      return e.message!;
    }
  }

  // TypeError from bad JSON casts, etc.
  if (e is TypeError || e is FormatException) {
    return 'Unexpected server response. The server may be unavailable.';
  }

  final msg = e.toString().toLowerCase();
  if (msg.contains('device_uuid')) {
    return 'This account is bound to another device. Contact your administrator.';
  }
  return fallback;
}

String _serverErrorMessage(int? status) {
  return 'Server error ($status). The API database may be down — '
      'check /api/v1/health/ or your Render/Django logs, then try again.';
}

String? _formatErrorMap(Map<String, dynamic> data) {
  if (data['detail'] != null) return data['detail'].toString();

  if (data['non_field_errors'] != null) {
    return _formatField('Error', data['non_field_errors']);
  }

  if (data['message'] != null) return data['message'].toString();

  if (data['errors'] is Map) {
    final nested = _collectFieldErrors(data['errors'] as Map);
    if (nested.isNotEmpty) return nested.join('\n');
  }

  const skip = {
    'detail',
    'message',
    'errors',
    'count',
    'next',
    'previous',
    'results',
    'status',
    'database',
    'system',
  };
  final lines = <String>[];
  for (final entry in data.entries) {
    if (skip.contains(entry.key)) continue;
    if (entry.value is List || entry.value is String) {
      lines.add(_formatField(entry.key, entry.value));
    }
  }
  if (lines.isNotEmpty) return lines.join('\n');

  return null;
}

List<String> _collectFieldErrors(Map errors) {
  final lines = <String>[];
  for (final entry in errors.entries) {
    lines.add(_formatField(entry.key.toString(), entry.value));
  }
  return lines;
}

String _formatField(String field, dynamic value) {
  final label = field.replaceAll('_', ' ');
  if (value is List) {
    return '$label: ${value.map((e) => e.toString()).join(', ')}';
  }
  return '$label: $value';
}

/// Human-readable message when GET /health/ reports database issues.
String? healthWarning(Map<String, dynamic>? health) {
  if (health == null) return null;
  if (health['database'] == 'error' || health['status'] == 'degraded') {
    return 'Server database is unavailable. Registration and login will fail '
        'until the backend database is fixed on Render.';
  }
  return null;
}
