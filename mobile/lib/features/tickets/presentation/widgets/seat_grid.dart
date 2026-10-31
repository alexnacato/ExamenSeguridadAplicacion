import 'package:flutter/material.dart';

import '../../domain/entities/ticket_models.dart';

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seatMap,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final SeatMap seatMap;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool enabled;

  static const _rows = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final row in _rows) ...[
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  row,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 1; i <= 10; i++) ...[
                      if (i > 1) const SizedBox(width: 4),
                      Expanded(
                        child: _SeatButton(
                          seat: '$row$i',
                          state: seatMap.seats['$row$i'] ?? SeatState.free,
                          selected: selected.contains('$row$i'),
                          enabled: enabled,
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (row != _rows.last) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.seat,
    required this.state,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String seat;
  final SeatState state;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = state == SeatState.locked || state == SeatState.sold;
    final canTap = enabled && !blocked;

    Color background;
    Color foreground;
    Color? borderColor;

    if (selected) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
      borderColor = scheme.primary;
    } else {
      switch (state) {
        case SeatState.mine:
          background = scheme.primaryContainer;
          foreground = scheme.onPrimaryContainer;
          borderColor = scheme.primary.withValues(alpha: .45);
          break;
        case SeatState.locked:
          background = scheme.tertiaryContainer.withValues(alpha: .65);
          foreground = scheme.onTertiaryContainer;
          borderColor = scheme.tertiary.withValues(alpha: .35);
          break;
        case SeatState.sold:
          background = scheme.surfaceContainerHighest;
          foreground = scheme.onSurfaceVariant.withValues(alpha: .55);
          borderColor = scheme.outlineVariant;
          break;
        case SeatState.free:
          background = scheme.surface;
          foreground = scheme.onSurface;
          borderColor = scheme.outlineVariant;
          break;
      }
    }

    return Tooltip(
      message: '$seat · ${_label(state)}',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: canTap ? () => onTap(seat) : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            seat.substring(1),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  String _label(SeatState state) {
    switch (state) {
      case SeatState.free:
        return 'Libre';
      case SeatState.mine:
        return 'Tu bloqueo';
      case SeatState.locked:
        return 'Bloqueado';
      case SeatState.sold:
        return 'Vendido';
    }
  }
}
