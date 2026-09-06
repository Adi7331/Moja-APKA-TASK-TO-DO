import 'package:flutter/material.dart';

class TaskStatusControl extends StatelessWidget {
  const TaskStatusControl({
    super.key,
    required this.status,
    required this.onStatusSelected,
  });

  final String status;
  final ValueChanged<String> onStatusSelected;

  static const _statuses = <String>['todo', 'in_progress', 'done'];
  static const _desktopLabelsMinWidth = 400.0;
  static const _labels = <String, String>{
    'todo': 'Do zrobienia',
    'in_progress': 'W trakcie',
    'done': 'Gotowe',
  };
  static const _icons = <String, IconData>{
    'todo': Icons.radio_button_unchecked,
    'in_progress': Icons.timelapse,
    'done': Icons.check_circle_outline,
  };

  String _nextStatus() {
    final index = _statuses.indexOf(status);
    return _statuses[(index < 0 ? 0 : index + 1) % _statuses.length];
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 720) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _desktopLabelsMinWidth;
          return Wrap(
            spacing: 4,
            children: [
              for (final value in _statuses)
                _DesktopStatusButton(
                  key: ValueKey('status-$value'),
                  value: value,
                  label: _labels[value]!,
                  icon: _icons[value]!,
                  selected: status == value,
                  compact: compact,
                  onTap: () => onStatusSelected(value),
                ),
            ],
          );
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-status-cycle'),
          onPressed: () => onStatusSelected(_nextStatus()),
          icon: Icon(_icons[_nextStatus()]),
          label: Text(_labels[_nextStatus()]!),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('mobile-status-options'),
          tooltip: 'Wybierz status',
          onSelected: onStatusSelected,
          icon: const Icon(Icons.more_vert),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          itemBuilder: (context) => [
            for (final value in _statuses)
              PopupMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    Icon(_icons[value]),
                    const SizedBox(width: 12),
                    Text(_labels[value]!),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DesktopStatusButton extends StatelessWidget {
  const _DesktopStatusButton({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: compact ? 48 : null,
            height: 48,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: compact
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: compact
                  ? Center(child: Icon(icon))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
