import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_outlined,
            size: 56,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 16),
          Text(
            'Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
