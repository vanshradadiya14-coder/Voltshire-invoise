import 'package:flutter/material.dart';

/// A small coloured pill used to show job/invoice/quote status.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.color, this.dense = false, super.key});

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
