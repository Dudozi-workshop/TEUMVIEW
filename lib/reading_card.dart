import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// A single reading takes precedence when a dashboard tile is resized.
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.detail,
    this.fraction,
    this.onTap,
    this.large = false,
  });

  final String label, value;
  final String? detail;
  final IconData? icon;
  final double? fraction;
  final VoidCallback? onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: [label, value, if (detail != null) detail!].join(', '),
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final header = bounds.maxHeight >= 62 && bounds.maxWidth >= 60;
            final footer = detail != null && bounds.maxHeight >= 92;
            final fontSize = (bounds.maxHeight * (large ? 0.78 : 0.52))
                .clamp(24.0, large ? 210.0 : 100.0)
                .toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header)
                  SizedBox(
                    height: 20,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 15, color: colors.primary),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (onTap != null)
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: fontSize,
                        height: 1.05,
                        color: colors.onSurface,
                        letterSpacing: -fontSize * 0.035,
                        fontWeight: large ? FontWeight.w400 : FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (fraction != null && bounds.maxHeight >= 42)
                  LinearProgressIndicator(
                    value: fraction,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                if (footer)
                  SizedBox(
                    height: 20,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
