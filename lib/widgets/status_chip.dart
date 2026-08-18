import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A modern coloured pill with a glowing status indicator dot.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    this.dense = false,
    this.showDot = true,
    super.key,
  });

  final String label;
  final Color color;
  final bool dense;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors statusColors = AppColors.of(context);
    final Color resolvedColor = statusColors.resolve(color);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resolvedColor.withValues(alpha: isDark ? 0.40 : 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: dense ? 5.5 : 6.5,
              height: dense ? 5.5 : 6.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: resolvedColor,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: resolvedColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            SizedBox(width: dense ? 4.5 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: resolvedColor,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
