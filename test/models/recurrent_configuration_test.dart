import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';

void main() {
  group('RecurrentConfiguration Model Tests', () {
    test('should correctly convert to map', () {
      final config = RecurrentConfig(
        frequency: RecurrentFrequency.weekly,
        interval: 2,
        weekdays: [1, 3, 5],
      );

      final map = config.toMap();

      expect(map['frequency'], RecurrentFrequency.weekly.index);
      expect(map['interval'], 2);
      expect(map['weekdays'], [1, 3, 5]);
    });

    test('should correctly create from map', () {
      final map = <String, dynamic>{
        'frequency': RecurrentFrequency.weekly.index,
        'interval': 2,
        'weekdays': [1, 3, 5],
      };

      final config = RecurrentConfig.fromMap(map);

      expect(config.frequency, RecurrentFrequency.weekly);
      expect(config.interval, 2);
      expect(config.weekdays, [1, 3, 5]);
    });

    test('fromMap should handle missing fields', () {
      final map = <String, dynamic>{};

      final config = RecurrentConfig.fromMap(map);

      expect(config.frequency, RecurrentFrequency.daily);
      expect(config.interval, 1);
      expect(config.weekdays, isNull);
    });

    test('fromMap should handle invalid frequency index', () {
      final map = <String, dynamic>{
        'frequency': 99,
      };

      final config = RecurrentConfig.fromMap(map);

      expect(config.frequency, RecurrentFrequency.daily);
    });

    test('toMap should handle null weekdays', () {
      final config = RecurrentConfig(frequency: RecurrentFrequency.daily);

      final map = config.toMap();

      expect(map['frequency'], RecurrentFrequency.daily.index);
      expect(map['interval'], 1);
      expect(map['weekdays'], isNull);
    });
  });
}
