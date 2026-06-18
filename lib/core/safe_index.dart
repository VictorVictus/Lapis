int safeIndex<T>(List<T> values, dynamic raw, int defaultIndex) {
  if (raw is! int) return defaultIndex;
  if (raw < 0 || raw >= values.length) return defaultIndex;
  return raw;
}
