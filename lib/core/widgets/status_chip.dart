import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small pill used for asset status, request status and condition.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  factory StatusChip.asset(BuildContext context, String status, String label,
      {bool dense = false}) {
    return StatusChip(
      label: label,
      color: StatusPalette.forAsset(context, status),
      icon: StatusPalette.iconForAsset(status),
      dense: dense,
    );
  }

  factory StatusChip.request(
    BuildContext context,
    String status,
    String label, {
    bool dense = false,
  }) {
    return StatusChip(
      label: label,
      color: StatusPalette.forRequest(context, status),
      icon: StatusPalette.iconForRequest(status),
      dense: dense,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            SizedBox(width: dense ? 4 : 6),
          ],
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}