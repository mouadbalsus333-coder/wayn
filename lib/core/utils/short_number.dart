/// تنسيق مختصر عام وقابل لإعادة الاستخدام للأرقام:
/// 1000 → 1K, 1500 → 1.5K, 10000 → 10K, 1000000 → 1M, 1500000 → 1.5M
String formatCount(num value) {
  final n = value.toDouble();

  if (n >= 1000000) {
    return _trim(n / 1000000) + 'M';
  }

  if (n >= 1000) {
    return _trim(n / 1000) + 'K';
  }

  return n.round().toString();
}

String _trim(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  final fixed = value.toStringAsFixed(1);

  return fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed;
}
