// Тест канона свайпов: удаление допустимо только слева, никогда справа.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/settings/swipe_action_provider.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;

Future<ProviderContainer> _container(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('свайп-канон: удаление только слева', () {
    test('дефолт: право=done, лево=skip', () async {
      final c = await _container({});
      final cfg = c.read(swipeActionsProvider);
      expect(cfg.right, SwipeAction.done);
      expect(cfg.left, SwipeAction.skip);
    });

    test('setRight(delete) санируется в done (удаление справа запрещено)', () async {
      final c = await _container({});
      await c.read(swipeActionsProvider.notifier).setRight(SwipeAction.delete);
      expect(c.read(swipeActionsProvider).right, SwipeAction.done);
    });

    test('setRight(snooze) допустим (позитив/нейтраль справа)', () async {
      final c = await _container({});
      await c.read(swipeActionsProvider.notifier).setRight(SwipeAction.snooze);
      expect(c.read(swipeActionsProvider).right, SwipeAction.snooze);
    });

    test('setLeft(delete) допустим — удаление слева разрешено', () async {
      final c = await _container({});
      await c.read(swipeActionsProvider.notifier).setLeft(SwipeAction.delete);
      expect(c.read(swipeActionsProvider).left, SwipeAction.delete);
    });

    test('старое сохранённое право=delete санируется в done при загрузке', () async {
      final c = await _container({'swipe_right_action': 'delete'});
      expect(c.read(swipeActionsProvider).right, SwipeAction.done);
    });
  });
}
