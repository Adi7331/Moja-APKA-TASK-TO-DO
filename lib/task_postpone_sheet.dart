import 'package:flutter/material.dart';

import 'task_schedule.dart';

Future<PostponeOption?> showTaskPostponeSheet(BuildContext context) =>
    showModalBottomSheet<PostponeOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Odłóż zadanie',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Wybierz, kiedy ma wrócić do Twojego planu.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _PostponeChoice(
                icon: Icons.schedule_outlined,
                label: 'Za godzinę',
                option: PostponeOption.oneHour,
              ),
              _PostponeChoice(
                icon: Icons.wb_sunny_outlined,
                label: 'Jutro rano',
                option: PostponeOption.tomorrowMorning,
              ),
              _PostponeChoice(
                icon: Icons.calendar_today_outlined,
                label: 'W poniedziałek',
                option: PostponeOption.nextMonday,
              ),
            ],
          ),
        ),
      ),
    );

class _PostponeChoice extends StatelessWidget {
  const _PostponeChoice({
    required this.icon,
    required this.label,
    required this.option,
  });

  final IconData icon;
  final String label;
  final PostponeOption option;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(option),
          icon: Icon(icon),
          label: Align(alignment: Alignment.centerLeft, child: Text(label)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.centerLeft,
          ),
        ),
      );
}
