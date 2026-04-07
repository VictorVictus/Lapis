enum RecurrentFrequency { daily, weekly, monthly, custom }

class RecurrentConfig {
  final RecurrentFrequency frequency;
  final int interval; // cada X dias/semanas
  final List<int>? weekdays; // 1=Mon ... 7=Sun

  RecurrentConfig({required this.frequency, this.interval = 1, this.weekdays});

  factory RecurrentConfig.fromMap(Map<String, dynamic> map) {
    return RecurrentConfig(
      frequency: RecurrentFrequency.values[map['frequency'] ?? 0],
      interval: map['interval'] ?? 1,
      weekdays: map['weekdays'] != null
          ? List<int>.from(map['weekdays'])
          : null,
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
