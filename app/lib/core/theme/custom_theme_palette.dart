// Алгоритм вывода пользовательской палитры из трёх входных параметров:
// базовый режим (dark/light), акцент (Color), смещение оттенка фона (−30..+30).
// Единственный источник математики — /docs/design/05-custom-theme.md §2–§3.
// Чистая функция: не импортирует Riverpod и не имеет побочных эффектов.
//
// Файл является частью библиотеки app_theme.dart (part of),
// чтобы получить доступ к приватному классу _Palette.
part of 'app_theme.dart';

/// Результат вывода акцента: итоговый цвет + флаг принудительной коррекции.
class _AccentResult {
  const _AccentResult({required this.color, required this.wasForced});
  final Color color;
  final bool wasForced;
}

/// Вспомогательный класс: HSL-тройка (hue 0..360, saturation 0..1, lightness 0..1).
class _HSL {
  const _HSL(this.h, this.s, this.l);
  final double h; // градусы
  final double s; // [0..1]
  final double l; // [0..1]
}

/// Класс вывода пользовательской палитры.
/// Используется из app_theme.dart через AppTheme.forKeyWithCustom.
class CustomThemePalette {
  CustomThemePalette._();

  // --- Открытый метод вывода ---

  /// Выводит полную [_Palette] из [config].
  /// Гарантирует WCAG-совместимость через бинарный поиск светлоты.
  static ({_Palette palette, bool accentWasForced}) derive(
      CustomThemeConfig config) {
    final isDark = config.isDark;
    final accentInput = config.accentColor;
    final delta = config.bgHueDelta.clamp(-30, 30);

    // Шаг 1: фон
    final bg = _deriveBg(isDark, accentInput, delta);

    // Шаг 2: surface, surfaceElevated
    final surface = _deriveSurface(isDark, bg);
    final surfaceElevated = _deriveSurfaceElevated(isDark, bg);

    // Шаг 3: text, textMuted, textFaint
    final text = _deriveText(isDark, accentInput);
    final textMuted = _adjustLightnessForContrast(
        isDark, _textMutedInitial(isDark, accentInput), surface, 4.5);
    final textFaint = _adjustLightnessForContrast(
        isDark, _textFaintInitial(isDark, accentInput), surface, 3.0);

    // Шаг 4: accent (с гарантией читаемости на bg)
    final accentResult = _deriveAccent(isDark, accentInput, bg);

    // Шаг 4b: accentMuted (непрозрачный для любого контекста)
    final accentMuted =
        _deriveAccentMuted(isDark, accentResult.color);

    // Шаг 5: onAccent — чёрный или белый
    final onAccent = _deriveOnAccent(accentResult.color);

    // Шаг 6: ember — тёплый красно-оранжевый, независимый от акцента
    final ember = _deriveEmber(isDark, accentInput, bg);

    // Шаг 7: success — фиксированный семантический зелёный
    final success = _deriveSuccess(isDark, bg);

    // Шаг 8: border, borderStrong
    final border = _deriveBorder(isDark, surface);
    final borderStrong = _deriveBorderStrong(isDark, surface);

    final palette = _Palette(
      brightness: isDark ? Brightness.dark : Brightness.light,
      bg: bg,
      surface: surface,
      surfaceElevated: surfaceElevated,
      text: text,
      textMuted: textMuted,
      textFaint: textFaint,
      accent: accentResult.color,
      accentMuted: accentMuted,
      onAccent: onAccent,
      ember: ember,
      success: success,
      border: border,
      borderStrong: borderStrong,
    );

    return (palette: palette, accentWasForced: accentResult.wasForced);
  }

  // ---------------------------------------------------------------------------
  // Шаг 1 — Фон
  // ---------------------------------------------------------------------------

  static Color _deriveBg(bool isDark, Color accent, int bgHueDelta) {
    final accentHsl = _toHSL(accent);
    final hue = (accentHsl.h + bgHueDelta) % 360.0;

    if (isDark) {
      // HSL (accentHue, 0.08, 0.07) с зажимом светлоты [0.05, 0.10]
      return _fromHSL(_HSL(hue, 0.08, 0.07.clamp(0.05, 0.10)));
    } else {
      // HSL (accentHue + delta, 0.04, 0.97) с зажимом [0.94, 0.99]
      return _fromHSL(_HSL(hue, 0.04, 0.97.clamp(0.94, 0.99)));
    }
  }

  // ---------------------------------------------------------------------------
  // Шаг 2 — Surface, SurfaceElevated
  // ---------------------------------------------------------------------------

  static Color _deriveSurface(bool isDark, Color bg) {
    final hsl = _toHSL(bg);
    if (isDark) {
      // светлота + 0.06, насыщенность * 0.85
      return _fromHSL(_HSL(hsl.h, (hsl.s * 0.85).clamp(0.0, 1.0),
          (hsl.l + 0.06).clamp(0.0, 1.0)));
    } else {
      // светлота − 0.04
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l - 0.04).clamp(0.0, 1.0)));
    }
  }

  static Color _deriveSurfaceElevated(bool isDark, Color bg) {
    final hsl = _toHSL(bg);
    if (isDark) {
      return _fromHSL(_HSL(hsl.h, (hsl.s * 0.75).clamp(0.0, 1.0),
          (hsl.l + 0.11).clamp(0.0, 1.0)));
    } else {
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l - 0.08).clamp(0.0, 1.0)));
    }
  }

  // ---------------------------------------------------------------------------
  // Шаг 3 — Текстовые цвета
  // ---------------------------------------------------------------------------

  static Color _deriveText(bool isDark, Color accent) {
    if (isDark) {
      // Тёплый почти-белый, не зависит от акцента (05-custom-theme.md §2 Шаг 3)
      return const Color(0xFFF0EDE6);
    } else {
      // HSL (accentHue, 0.05, 0.10) — почти-чёрный с оттенком акцента
      final h = _toHSL(accent).h;
      return _fromHSL(_HSL(h, 0.05, 0.10));
    }
  }

  static Color _textMutedInitial(bool isDark, Color accent) {
    final h = _toHSL(accent).h;
    if (isDark) {
      return _fromHSL(_HSL(h, 0.06, 0.55));
    } else {
      return _fromHSL(_HSL(h, 0.05, 0.42));
    }
  }

  static Color _textFaintInitial(bool isDark, Color accent) {
    final h = _toHSL(accent).h;
    if (isDark) {
      return _fromHSL(_HSL(h, 0.05, 0.43));
    } else {
      return _fromHSL(_HSL(h, 0.04, 0.58));
    }
  }

  // ---------------------------------------------------------------------------
  // Шаг 4 — Акцент
  // ---------------------------------------------------------------------------

  static _AccentResult _deriveAccent(bool isDark, Color accent, Color bg) {
    var hsl = _toHSL(accent);
    Color current = accent;
    bool forced = false;
    const int maxIter = 20;
    const double step = 0.02;

    for (int i = 0; i < maxIter; i++) {
      if (_contrastRatio(current, bg) >= 3.0) break;
      if (i == maxIter - 1) {
        // Принудительный откат к дефолтному акценту темы
        current = isDark ? const Color(0xFFD9F24B) : const Color(0xFF2B6CB0);
        forced = true;
        break;
      }
      if (isDark) {
        hsl = _HSL(hsl.h, hsl.s, (hsl.l + step).clamp(0.0, 1.0));
      } else {
        hsl = _HSL(hsl.h, hsl.s, (hsl.l - step).clamp(0.0, 1.0));
      }
      current = _fromHSL(hsl);
    }

    return _AccentResult(color: current, wasForced: forced);
  }

  static Color _deriveAccentMuted(bool isDark, Color accent) {
    // Непрозрачный вариант: насыщенность * 0.4, светлота ±
    final hsl = _toHSL(accent);
    if (isDark) {
      // В тёмном: сильно затемняем (−0.20)
      return _fromHSL(_HSL(hsl.h, (hsl.s * 0.4).clamp(0.0, 1.0),
          (hsl.l - 0.20).clamp(0.0, 1.0)));
    } else {
      // В светлом: осветляем (+0.15)
      return _fromHSL(_HSL(hsl.h, (hsl.s * 0.4).clamp(0.0, 1.0),
          (hsl.l + 0.15).clamp(0.0, 1.0)));
    }
  }

  // ---------------------------------------------------------------------------
  // Шаг 5 — onAccent: чёрный или белый
  // ---------------------------------------------------------------------------

  static Color _deriveOnAccent(Color accent) {
    const black = Color(0xFF0A0A0A);
    const white = Color(0xFFFAFAFA);
    return _contrastRatio(black, accent) >= 4.5 ? black : white;
  }

  // ---------------------------------------------------------------------------
  // Шаг 6 — Ember (тёплый красно-оранжевый)
  // ---------------------------------------------------------------------------

  static Color _deriveEmber(bool isDark, Color accent, Color bg) {
    const Color baseEmber = Color(0xFFFF6A3D);
    final accentHue = _toHSL(accent).h;

    // Если акцент близок к оттенку ember (hue ~25), сдвигаем в 340 (тёмно-розовый)
    Color ember = baseEmber;
    if ((accentHue - 25).abs() < 30) {
      final emberHsl = _toHSL(baseEmber);
      ember = _fromHSL(_HSL(340, emberHsl.s, emberHsl.l));
    }

    // Проверяем CR >= 3.0 на фоне
    return _adjustLightnessForContrast(isDark, ember, bg, 3.0);
  }

  // ---------------------------------------------------------------------------
  // Шаг 7 — Success (фиксированный семантический зелёный)
  // ---------------------------------------------------------------------------

  static Color _deriveSuccess(bool isDark, Color bg) {
    final initial =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    return _adjustLightnessForContrast(isDark, initial, bg, 3.0);
  }

  // ---------------------------------------------------------------------------
  // Шаг 8 — Border, BorderStrong
  // ---------------------------------------------------------------------------

  static Color _deriveBorder(bool isDark, Color surface) {
    final hsl = _toHSL(surface);
    if (isDark) {
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l + 0.07).clamp(0.0, 1.0)));
    } else {
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l - 0.08).clamp(0.0, 1.0)));
    }
  }

  static Color _deriveBorderStrong(bool isDark, Color surface) {
    final hsl = _toHSL(surface);
    if (isDark) {
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l + 0.15).clamp(0.0, 1.0)));
    } else {
      return _fromHSL(
          _HSL(hsl.h, hsl.s, (hsl.l - 0.18).clamp(0.0, 1.0)));
    }
  }

  // ---------------------------------------------------------------------------
  // Бинарный поиск светлоты для соответствия WCAG
  // ---------------------------------------------------------------------------

  /// Корректирует светлоту [color] бинарным поиском (32 итерации),
  /// чтобы CR([result], [background]) >= [targetCR].
  static Color _adjustLightnessForContrast(
      bool isDark, Color color, Color background, double targetCR) {
    if (_contrastRatio(color, background) >= targetCR) return color;

    final hsl = _toHSL(color);

    // В тёмном режиме: осветляем (ищем более высокую светлоту).
    // В светлом режиме: затемняем (ищем более низкую светлоту).
    double lo = isDark ? hsl.l : 0.0;
    double hi = isDark ? 1.0 : hsl.l;

    Color best = color;
    for (int i = 0; i < 32; i++) {
      final mid = (lo + hi) / 2.0;
      final candidate = _fromHSL(_HSL(hsl.h, hsl.s, mid));
      if (_contrastRatio(candidate, background) >= targetCR) {
        best = candidate;
        if (isDark) {
          hi = mid; // минимизируем светлоту, оставаясь над порогом
        } else {
          lo = mid; // максимизируем светлоту, оставаясь над порогом
        }
      } else {
        if (isDark) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Математика WCAG (05-custom-theme.md §2 Шаг 0)
  // ---------------------------------------------------------------------------

  /// Относительная яркость по WCAG 2.1 §1.4.3.
  static double _relativeLuminance(Color c) {
    double lin(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  }

  /// Коэффициент контрастности WCAG.
  static double _contrastRatio(Color fg, Color bg) {
    final lf = _relativeLuminance(fg);
    final lb = _relativeLuminance(bg);
    final lighter = math.max(lf, lb);
    final darker = math.min(lf, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  // ---------------------------------------------------------------------------
  // HSL ↔ Color
  // ---------------------------------------------------------------------------

  static _HSL _toHSL(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;

    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2.0;

    if (maxC == minC) return _HSL(0, 0, l);

    final d = maxC - minC;
    final s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);

    double h;
    if (maxC == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxC == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h = (h / 6.0) * 360.0;

    return _HSL(h, s, l);
  }

  static Color _fromHSL(_HSL hsl) {
    final h = hsl.h / 360.0;
    final s = hsl.s;
    final l = hsl.l;

    if (s == 0) {
      return Color.from(alpha: 1.0, red: l, green: l, blue: l);
    }

    double hue2rgb(double p, double q, double t) {
      double tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return p + (q - p) * 6 * tt;
      if (tt < 1 / 2) return q;
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;

    return Color.from(
      alpha: 1.0,
      red: hue2rgb(p, q, h + 1 / 3),
      green: hue2rgb(p, q, h),
      blue: hue2rgb(p, q, h - 1 / 3),
    );
  }
}
