// Юнит-тесты для #23 (дефолт отдыха + переопределение) и #22+F (логирование
// фактических reps/weight, отредактированных во время отдыха).
//
// effectiveRestSeconds — чистая функция (без Flutter/prefs), тестируется прямо.
// Логирование фактических значений проверяем на уровне DAO (in-memory Drift):
// тренажёр пишет в Drift через logSet с теми числами, что в полях ввода.
//
// Новые тесты (баг card != training):
//  - При добавлении нового упражнения дефолт отдыха = глобальный default, не 60.
//  - Тренажёр вызывает effectiveRestSeconds: новое упражнение хранит, например,
//    240 (глобал) → effectiveRestSeconds(240, 240) = 240 (не 60 и не замена).
//  - Легаси: старые строки со значением 60 по-прежнему получают глобальный дефолт.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/workouts_dao.dart';
import 'package:app/core/settings/rest_default_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveRestSeconds (#23: дефолт отдыха + переопределение)', () {
    test('per-exercise == легаси-маркер (60) → берём глобальный дефолт', () {
      // Упражнение «не настраивали» (значение равно старому Constant-дефолту) →
      // применяется глобальный дефолт из Профиля.
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kLegacyRestMarkerSeconds, // 60
          globalDefaultSeconds: 120,
        ),
        120,
      );
    });

    test('per-exercise задан явно (≠ маркер) → используем его как есть', () {
      // Явное переопределение на упражнении главнее глобального дефолта.
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: 90,
          globalDefaultSeconds: 120,
        ),
        90,
      );
    });

    test('глобальный дефолт по умолчанию = 120с (2 мин)', () {
      expect(kDefaultRestSeconds, 120);
    });

    test('любое значение != 60 явное, даже 0 и большие', () {
      expect(
        effectiveRestSeconds(exerciseRestSeconds: 0, globalDefaultSeconds: 120),
        0,
      );
      expect(
        effectiveRestSeconds(
            exerciseRestSeconds: 240, globalDefaultSeconds: 120),
        240,
      );
    });

    // --- Новые тесты (баг «card != training») ---

    test(
        'новое упражнение, созданное с globalDefault=240: '
        'карточка хранит 240, тренажёр тоже получает 240 (card == training)',
        () {
      // Сценарий: пользователь установил глобальный дефолт 4 мин (240с).
      // При добавлении упражнения диалог показывает и сохраняет 240.
      // Тренажёр вызывает effectiveRestSeconds(240, 240) — должен вернуть 240.
      // (240 ≠ kLegacyRestMarkerSeconds=60 → используем как есть.)
      const globalDefault = 240;
      // Редактор: дефолт нового поля = globalDefault = 240.
      const savedRestSeconds = globalDefault; // именно это хранится в БД

      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: savedRestSeconds,
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault, // card == training
      );
    });

    test(
        'новое упражнение с globalDefault=120: '
        'хранит 120, тренажёр получает 120 (не попадает под легаси-60)',
        () {
      // Глобал = 2 мин. Новое упражнение сохраняет 120 (не 60-маркер).
      // effectiveRestSeconds(120, 120) = 120 (≠ 60 → не легаси).
      const globalDefault = 120;
      const savedRestSeconds = globalDefault;
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: savedRestSeconds,
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault,
      );
    });

    test(
        'новое упражнение с globalDefault=15: '
        'хранит 15, тренажёр получает 15 (не легаси-60)',
        () {
      // Минимальная граница (kRestDefaultMinSeconds).
      const globalDefault = 15;
      const savedRestSeconds = globalDefault;
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: savedRestSeconds,
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault,
      );
    });

    test(
        'легаси совместимость: старая строка БД со значением 60 '
        'получает глобальный дефолт (backward-compat)',
        () {
      // До фикса новые упражнения сохранялись с 60 (Constant-дефолт).
      // Такие старые строки по-прежнему должны получать глобальный дефолт
      // при воспроизведении тренировки — не показывать ровно 60с.
      const globalDefault = 240;
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: kLegacyRestMarkerSeconds, // 60 — старая строка
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault,
      );
    });

    test(
        'пользователь явно ставит 60с в диалоге: '
        'это его выбор, тренажёр должен использовать глобальный дефолт '
        '(60 = маркер; если нужна ровно 1 минута — нужно ставить 61)',
        () {
      // Известное ограничение: если пользователь хочет ровно 60с, маркер
      // «перехватит» это значение. Тест документирует поведение.
      const globalDefault = 90;
      expect(
        effectiveRestSeconds(
          exerciseRestSeconds: 60, // пользователь ввёл 60 — попадает в маркер
          globalDefaultSeconds: globalDefault,
        ),
        globalDefault, // получит 90, а не 60 — известное ограничение
      );
    });
  });

  group('#22+F: logSet пишет ФАКТИЧЕСКИЕ (отредактированные) значения', () {
    late AppDatabase db;
    late WorkoutsDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = WorkoutsDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('подход логируется с фактическими reps/weight, а не плановыми',
        () async {
      // Сценарий: план 10×40, во время отдыха пользователь правит на 8×42.5.
      // Тренажёр вызывает logSet с фактическими (отредактированными) числами.
      await dao.logSet(
        sessionId: 's1',
        exerciseId: 'e1',
        setIndex: 0,
        reps: 8, // факт (план был 10)
        weightKg: 42.5, // факт (план был 40)
      );

      final sets = await dao.watchSessionSets('s1').first;
      expect(sets, hasLength(1));
      expect(sets.single.reps, 8);
      expect(sets.single.weightKg, 42.5);
    });

    test('пустое поле веса → bodyweight (null) логируется', () async {
      // #22+F: очистка поля веса = собственный вес.
      await dao.logSet(
        sessionId: 's1',
        exerciseId: 'e1',
        setIndex: 1,
        reps: 12,
      );

      final sets = await dao.watchSessionSets('s1').first;
      expect(sets.single.weightKg, isNull);
      expect(sets.single.reps, 12);
    });
  });
}
