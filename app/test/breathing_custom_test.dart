// Юнит-тесты кодека пользовательских дыхательных техник (breathing_custom.dart).
// Чистые функции encodePhases/decodePhases — без Flutter/Drift.
// Проверяем: пустой список, одна фаза, все типы фаз, сохранение порядка,
// точный round-trip и безопасную деградацию битого JSON в пустой список.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/health/breathing_custom.dart';
import 'package:app/features/health/breathing_engine.dart';

void main() {
  group('encode/decode round-trip', () {
    test('пустой список → "[]" → пустой список', () {
      final json = encodePhases(const []);
      expect(json, '[]');
      expect(decodePhases(json), isEmpty);
    });

    test('одна фаза round-trip сохраняет все поля', () {
      const phases = [
        BreathPhase(
            label: 'Inhale', duration: Duration(seconds: 4), expand: true),
      ];
      final decoded = decodePhases(encodePhases(phases));
      expect(decoded, hasLength(1));
      expect(decoded.first.label, 'Inhale');
      expect(decoded.first.duration, const Duration(seconds: 4));
      expect(decoded.first.expand, true);
      expect(decoded.first.hold, false);
    });

    test('все типы фаз (Inhale/Hold/Exhale) round-trip', () {
      const phases = [
        BreathPhase(
            label: 'Inhale', duration: Duration(seconds: 4), expand: true),
        BreathPhase(
            label: 'Hold',
            duration: Duration(seconds: 7),
            expand: true,
            hold: true),
        BreathPhase(
            label: 'Exhale', duration: Duration(seconds: 8), expand: false),
      ];
      final decoded = decodePhases(encodePhases(phases));
      expect(decoded.map((p) => p.label).toList(),
          ['Inhale', 'Hold', 'Exhale']);
      expect(decoded.map((p) => p.duration.inSeconds).toList(), [4, 7, 8]);
      expect(decoded[1].hold, true);
      expect(decoded[2].expand, false);
    });

    test('порядок фаз сохраняется (4 фазы Box)', () {
      final phases = breathingPresets[0].phases; // Box 4-4-4-4
      final decoded = decodePhases(encodePhases(phases));
      expect(decoded, hasLength(phases.length));
      for (var i = 0; i < phases.length; i++) {
        expect(decoded[i].label, phases[i].label);
        expect(decoded[i].duration, phases[i].duration);
        expect(decoded[i].expand, phases[i].expand);
        expect(decoded[i].hold, phases[i].hold);
      }
    });
  });

  group('decode — безопасная деградация', () {
    test('битый JSON → пустой список', () {
      expect(decodePhases('not json {{{'), isEmpty);
    });

    test('пустая строка → пустой список', () {
      expect(decodePhases(''), isEmpty);
    });

    test('JSON-объект (не массив) → пустой список', () {
      expect(decodePhases('{"label":"Inhale"}'), isEmpty);
    });

    test('JSON null → пустой список', () {
      expect(decodePhases('null'), isEmpty);
    });

    test('массив с мусором: невалидные элементы отброшены, валидные оставлены',
        () {
      // Один валидный объект + строка + объект без seconds + seconds<=0.
      const json =
          '[{"label":"Inhale","seconds":4,"expand":true,"hold":false},'
          '"garbage",'
          '{"label":"Hold"},'
          '{"label":"Exhale","seconds":0,"expand":false,"hold":false}]';
      final decoded = decodePhases(json);
      expect(decoded, hasLength(1));
      expect(decoded.first.label, 'Inhale');
    });

    test('seconds как число с плавающей точкой усекается до int', () {
      const json = '[{"label":"Inhale","seconds":4.9,"expand":true}]';
      final decoded = decodePhases(json);
      expect(decoded, hasLength(1));
      expect(decoded.first.duration.inSeconds, 4);
    });
  });
}
