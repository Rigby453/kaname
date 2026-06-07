// Экран Health — хаб здоровья. Полноценные модули (тренировки, сон, дыхание,
// осанка) относятся к Phase 2; пока показываем понятную заглушку «скоро».

import 'package:flutter/material.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  static const _planned = [
    (Icons.fitness_center, 'Workouts'),
    (Icons.bedtime_outlined, 'Sleep'),
    (Icons.air, 'Breathing'),
    (Icons.self_improvement, 'Posture'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Health', style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Coming soon — workouts, sleep, breathing and posture will live here.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ..._planned.map((e) {
            final (icon, label) = e;
            return Card(
              child: ListTile(
                leading: Icon(
                  icon,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                title: Text(label),
                trailing: Text('soon', style: textTheme.bodySmall),
                enabled: false,
              ),
            );
          }),
        ],
      ),
    );
  }
}
