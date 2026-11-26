import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/diary_controller.dart';
import '../format.dart';

/// Moves the diary between days.
///
/// Tapping the label opens a date picker; the arrows step one day at a time.
/// Future days are allowed on purpose — that is how a plan gets made ahead.
class DaySwitcher extends StatelessWidget {
  const DaySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiaryController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Forrige dag',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => controller.shiftDay(-1),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: controller.selectedDay,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              locale: const Locale('nb', 'NO'),
            );
            if (picked != null) await controller.selectDay(picked);
          },
          child: Text(
            formatDayLabel(controller.selectedDay),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Neste dag',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => controller.shiftDay(1),
        ),
      ],
    );
  }
}
