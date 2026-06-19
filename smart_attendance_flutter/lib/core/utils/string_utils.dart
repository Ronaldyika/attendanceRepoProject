extension NullableStringExtensions on String? {
  String safeInitial([String fallback = 'S']) {
    final value = this?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value[0].toUpperCase();
  }

  String truncate(int maxLength, [String suffix = '']) {
    if (this == null || this!.isEmpty) return '';
    final value = this!;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}$suffix';
  }
}
