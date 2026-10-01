import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/credit_card_extensions.dart';
import '../../../theme/app_theme.dart';

class CreditCardItemCard extends StatelessWidget {
  final CreditCard card;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback? onPayment;

  const CreditCardItemCard({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onDeactivate,
    this.onPayment,
  });

  Color _getUtilizationColor(double utilization) {
    if (utilization >= 80.0) {
      return Colors.red.shade600;
    }
    if (utilization >= 30.0) {
      return const Color(0xFFD97706); // Amber 600
    }
    return AppTheme.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    final utilization = card.utilizationPercentage;
    final progress = (card.outstandingBalance /
            (card.creditLimit > 0 ? card.creditLimit : 1.0))
        .clamp(0.0, 1.0);
    final utilizationColor = _getUtilizationColor(utilization);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Card Icon + Name + Last 4 & Actions Menu
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.secondaryColor.withValues(alpha: 0.8),
                        AppTheme.secondaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '•••• ${card.lastFourDigits}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Utilization Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: utilizationColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${utilization.toStringAsFixed(1)}% Used',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: utilizationColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Options Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'deactivate') {
                      onDeactivate();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.primaryColor),
                          SizedBox(width: 10),
                          Text('Edit Card'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Row(
                        children: [
                          Icon(Icons.block_outlined,
                              size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 10),
                          const Text('Deactivate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Utilization Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
              ),
            ),
            const SizedBox(height: 16),

            // 3-Column Financial Metrics Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OUTSTANDING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(card.outstandingBalance),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CREDIT LIMIT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(card.creditLimit),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AVAILABLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(card.availableCredit),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Credit Limit amount in middle column
            // Let's ensure Credit Limit value is rendered properly
            // Informational Billing cycle / Payment due footer
            if (card.billingCycleDay != null || card.paymentDueDay != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    if (card.billingCycleDay != null)
                      Text(
                        'Bill Day: ${card.billingCycleDay}th',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (card.billingCycleDay != null &&
                        card.paymentDueDay != null)
                      const Text(
                        '  •  ',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    if (card.paymentDueDay != null)
                      Text(
                        'Due Day: ${card.paymentDueDay}th',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (onPayment != null) ...[
              const SizedBox(height: 14),
              if (card.outstandingBalance > 0)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPayment,
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Make Payment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('No Payment Due'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
