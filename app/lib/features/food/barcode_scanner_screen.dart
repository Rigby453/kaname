// Полноэкранный сканер штрихкода (Food, Ф1, SPEC C5 «ввод: штрихкод»).
// Возвращает считанный код через Navigator.pop(code) — дальше food_screen
// сам ходит в /api/v1/food/barcode и открывает диалог порции.
//
// Дизайн: чёрный фон — намеренный (камера, темнота улучшает сканирование),
// НЕ тема приложения. Белые наложения — контраст поверх видеопотока.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/l10n/app_strings.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // mobile_scanner 6+: внешний контроллер виджет НЕ стартует сам —
  // без start() камера падала ("Attempt to invoke virtual method").
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );

  // Камера может детектить один и тот же код много раз — закрываемся один раз.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => RegExp(r'^\d{6,14}$').hasMatch(v))
        .firstOrNull;
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    // Экран сканера — намеренно чёрный (камера): НЕ тема-поверхность.
    // Белые наложения — контраст поверх видеопотока (недизайнерский выбор, а UX).
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.s('food.scan_barcode_title')),
        // Переопределяем только для этого экрана — камера требует тёмного фона
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Фонарик: иконка следит за состоянием контроллера; до запуска
          // камеры toggle не зовём (иначе нативный краш на части устройств).
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? context.s('food.torch_off') : context.s('food.torch_on'),
                icon: Icon(
                  on
                      ? Icons.flashlight_on
                      : Icons.flashlight_on_outlined,
                  // Включённый фонарик — amber (ситуативный, не тема)
                  color: on ? Colors.amber : Colors.white,
                ),
                onPressed: state.isRunning
                    ? () => _controller.toggleTorch()
                    : null,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Рамка-прицел по центру — белая, тонкая (hairline-like, 1.5dp)
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                // Полупрозрачная белая заливка для улучшения видимости рамки
                border: Border.all(
                  color: Colors.white.withAlpha(180),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Инструкция внизу — bodyMedium с белым цветом (поверх камеры)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.s('food.scan_instruction'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withAlpha(180)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
