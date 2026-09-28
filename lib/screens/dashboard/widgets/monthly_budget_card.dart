import 'package:flutter/material.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/services/budget_service.dart';
import '../../../theme/app_theme.dart';

class MonthlyBudgetCard extends StatelessWidget {
  final BudgetSummary summary;
  final VoidCallback onEdit;

  const MonthlyBudgetCard({
    super.key,
    required this.summary,
    required this.onEdit,
  });

  Color _getStatusColor() {
    switch (summary.status) {
      case BudgetStatus.underBudget:
        return AppTheme.primaryColor;
      case BudgetStatus.nearLimit:
        return const Color(0xFFD97706); // Amber 600
      case BudgetStatus.overBudget:
        return Colors.red.shade600;
    }
  }

  Color _getStatusBgColor() {
    switch (summary.status) {
      case BudgetStatus.underBudget:
        return AppTheme.primaryContainer.withValues(alpha: 0.6);
      case BudgetStatus.nearLimit:
        return Colors.amber.shade100;
      case BudgetStatus.overBudget:
        return Colors.red.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusBgColor = _getStatusBgColor();
    final isOverBudget = summary.status == BudgetStatus.overBudget;

    final spentFormatted = CurrencyFormatter.format(summary.spending);
    final budgetFormatted = CurrencyFormatter.format(summary.budget);
    final remainingFormatted = CurrencyFormatter.format(summary.remaining.abs());
    final usageText = '${summary.usagePercentage.toStringAsFixed(1)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Label, Edit Action, and Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'MONTHLY BUDGET',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: AppTheme.textSecondary,
                      tooltip: 'Edit Budget',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onEdit,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Budget Amount
            Text(
              budgetFormatted,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.visualProgress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),

            // Spending and Remaining Details Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPENT',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spentFormatted,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isOverBudget ? 'OVER BUDGET' : 'REMAINING',
                      style: TextStyle(
                        color: isOverBudget
                            ? Colors.red.shade700
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOverBudget
                          ? CurrencyFormatter.format(summary.overrun)
                          : remainingFormatted,
                      style: TextStyle(
                        color: isOverBudget
                            ? Colors.red.shade700
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${summary.statusLabel} ($usageText)',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
