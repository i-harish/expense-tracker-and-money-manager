import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/financial_summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          const Text(
            'Good morning, Harish',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Cash Available Card
          const FinancialSummaryCard(
            label: 'CASH AVAILABLE',
            amount: '₹0',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),

          // Net Liquidity Card
          const FinancialSummaryCard(
            label: 'NET LIQUIDITY',
            amount: '₹0',
            icon: Icons.savings_outlined,
            accentColor: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 12),

          // Monthly Budget Card
          const FinancialSummaryCard(
            label: 'MONTHLY BUDGET',
            amount: '₹9,000',
            subtitle: '₹0 spent',
            icon: Icons.pie_chart_outline,
            accentColor: Color(0xFFD97706),
          ),
          const SizedBox(height: 28),

          // Recent Transactions Section Header
          const Text(
            'Recent Transactions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Empty Transactions Placeholder Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 44,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
