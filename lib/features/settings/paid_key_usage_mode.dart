/// Defines how the paid API key should be used.
enum PaidKeyUsageMode {
  /// Use paid key only when the free key hits a rate limit.
  fallback,

  /// Always use the paid key as the default.
  asDefault,

  /// Use paid key at a configurable rate per minute.
  rateBased,
}

extension PaidKeyUsageModeExtension on PaidKeyUsageMode {
  String get displayName {
    switch (this) {
      case PaidKeyUsageMode.fallback:
        return 'Fallback';
      case PaidKeyUsageMode.asDefault:
        return 'Default';
      case PaidKeyUsageMode.rateBased:
        return 'Rate-Based';
    }
  }

  String get description {
    switch (this) {
      case PaidKeyUsageMode.fallback:
        return 'Use paid key only when free key hits rate limit';
      case PaidKeyUsageMode.asDefault:
        return 'Always use the paid key';
      case PaidKeyUsageMode.rateBased:
        return 'Use at a configurable rate per minute';
    }
  }
}
