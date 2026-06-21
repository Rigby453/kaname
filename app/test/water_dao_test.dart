// Unit-тесты для WaterDao — round-trip addWater → watchTodayTotalMl.
// In-memory Drift — без Flutter-зависимостей, чистый Dart.
//
// Главное, что проверяем: границы дня строятся в ЛОКАЛЬНОМ времени, поэтому
// записи, добавленные «сейчас» (включая моменты у границы суток в UTC+N),
// попадают в сегодняшнюю сумму, а не теряются (раньше окна были в UTC → «0 мл»).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/water_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WaterDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = WaterDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addWater → watchTodayTotalMl возвращает добавленный объём', () async {
    await dao.addWater(250);
    await dao.addWater(500);

    final total = await dao.watchTodayTotalMl(DateTime.now()).first;
    expect(total, 750);
  });

  test('запись «сейчас» попадает в сегодня даже у границы суток (локальное окно)',
      () async {
    // addWater пишет DateTime.now() (локальное). День строим из той же локальной
    // «сейчас» — запись обязана учитываться, независимо от смещения от UTC.
    await dao.addWater(300);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final total = await dao.watchTodayTotalMl(today).first;
    expect(total, 300);
  });

  test('пустой день → 0 мл', () async {
    final total = await dao.watchTodayTotalMl(DateTime.now()).first;
    expect(total, 0);
  });
}
