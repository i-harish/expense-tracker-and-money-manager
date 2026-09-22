import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FinancialSummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;

  const FinancialSummaryCard({
    super.key,
    required this.label,
    required this.amount,
    this.subtitle,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? AppTheme.primaryColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: effectiveAccentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: effectiveAccentColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
