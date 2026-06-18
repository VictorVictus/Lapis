enum RecurrentFrequency { daily, weekly, monthly, custom }

class RecurrentConfig {
  final RecurrentFrequency frequency;
  final int interval; // cada X dias/semanas
  final List<int>? weekdays; // 1=Mon ... 7=Sun

  RecurrentConfig({required this.frequency, this.interval = 1, this.weekdays});

  factory RecurrentConfig.fromMap(Map<String, dynamic> map) {
    final freqRaw = map['frequency'];
    final freq = freqRaw is int && freqRaw >= 0 && freqRaw < RecurrentFrequency.values.length
        ? RecurrentFrequency.values[freqRaw]
        : RecurrentFrequency.daily;
    return RecurrentConfig(
      frequency: freq,
      interval: (map['interval'] as num?)?.toInt() ?? 1,
      weekdays: map['weekdays'] is List ? List<int>.from(map['weekdays'] as List) : null,
    );
  }

  RecurrentConfig copyWith({
    RecurrentFrequency? frequency,
    int? interval,
    List<int>? weekdays,
  }) {
    return RecurrentConfig(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.index,
      'interval': interval,
      'weekdays': weekdays,
    };
  }
}
