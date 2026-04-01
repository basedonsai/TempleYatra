import 'package:flutter/material.dart';
import '../models/festival_event.dart';

const _colors = {
  CrowdLevel.low: Colors.green,
  CrowdLevel.moderate: Colors.amber,
  CrowdLevel.high: Colors.red,
};

const _labels = {
  CrowdLevel.low: 'Low Crowd',
  CrowdLevel.moderate: 'Moderate',
  CrowdLevel.high: 'High Crowd',
};

class CrowdBadge extends StatelessWidget {
  final CrowdLevel level;
  final bool compact;

  const CrowdBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = _colors[level]!;
    final label = _labels[level]!;

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (compact) {
      return Tooltip(
        message: label,
        child: dot,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
