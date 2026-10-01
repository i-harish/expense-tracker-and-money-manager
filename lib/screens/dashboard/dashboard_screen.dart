import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/transactions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/services/budget_service.dart';
import '../../data/services/financial_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/financial_summary_card.dart';
import 'widgets/budget_edit_dialog.dart';
import 'widgets/monthly_budget_card.dart';

class DashboardScreen extends StatefulWidget {
  final FinancialService? financialService;
  final BudgetService? budgetService;

  const DashboardScreen({
    super.key,
    this.financialService,
    this.budgetService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final FinancialService _financialService;
  late final BudgetService _budgetService;

  double _cashAvailable = 0.0;
  double _netLiquidity = 0.0;
  BudgetSummary? _budgetSummary;
  List<TransactionWithAccount> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance;
    _financialService =
        widget.financialService ?? DriftFinancialService(db);
    _budgetService = widget.budgetService ?? DriftBudgetService(db);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final cash = await _financialService.getCashAvailable();
      final netLiquidity = await _financialService.getNetLiquidity();
      final budget = await _budgetService.getMonthlyBudgetSummary();
      final allTx = await _financialService.getTransactionsWithAccount();

      if (mounted) {
        setState(() {
          _cashAvailable = cash;
          _netLiquidity = netLiquidity;
          _budgetSummary = budget;
          _recentTransactions = allTx.take(5).toList();
        });
      }
    } catch (_) {
      // Ignored
    }
  }

  Future<void> _openEditBudgetDialog() async {
    if (_budgetSummary == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BudgetEditDialog(
        currentBudget: _budgetSummary!.budget,
        budgetService: _budgetService,
      ),
    );

    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashFormatted = CurrencyFormatter.format(_cashAvailable);
    final netLiquidityFormatted = CurrencyFormatter.format(_netLiquidity);
    final summary = _budgetSummary ??
        const BudgetSummary(
          period: '2026-09',
          budget: 9000.0,
          spending: 0.0,
        );

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
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
            FinancialSummaryCard(
              label: 'CASH AVAILABLE',
              amount: cashFormatted,
              icon: Icons.account_balance_wallet_outlined,
              accentColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 12),

            // Net Liquidity Card
            FinancialSummaryCard(
              label: 'NET LIQUIDITY',
              amount: netLiquidityFormatted,
              icon: Icons.savings_outlined,
              accentColor: AppTheme.secondaryColor,
            ),
            const SizedBox(height: 12),

            // Monthly Budget Card
            MonthlyBudgetCard(
              summary: summary,
              onEdit: _openEditBudgetDialog,
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

            // Recent Transactions List or Empty Placeholder
            if (_recentTransactions.isEmpty)
              Card(
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _recentTransactions[index];
                  final tx = item.transaction;
                  final account = item.account;
                  final card = item.creditCard;
                  final isIncome = tx.type == TransactionType.income;
                  final isCreditCardPurchase =
                      tx.type == TransactionType.creditCardPurchase;
                  final isCreditCardPayment =
                      tx.type == TransactionType.creditCardPayment;

                  final title = tx.description?.isNotEmpty == true
                      ? tx.description!
                      : (isIncome
                          ? 'Income'
                          : (isCreditCardPayment
                              ? '${card?.name ?? 'Credit Card'} Bill Payment'
                              : (isCreditCardPurchase
                                  ? '${card?.name ?? 'Credit Card'} Purchase'
                                  : 'Expense')));
                  final amountPrefix = isIncome ? '+' : '-';
                  final amountColor = isIncome
                      ? const Color(0xFF16A34A)
                      : Colors.red.shade700;

                  final iconData = isIncome
                      ? Icons.arrow_upward
                      : (isCreditCardPayment
                          ? Icons.payments_outlined
                          : (isCreditCardPurchase
                              ? Icons.credit_card_outlined
                              : Icons.arrow_downward));

                  final iconBgColor = isIncome
                      ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                      : (isCreditCardPayment
                          ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                          : (isCreditCardPurchase
                              ? AppTheme.secondaryColor.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12)));

                  final iconColor = isIncome
                      ? const Color(0xFF16A34A)
                      : (isCreditCardPayment
                          ? const Color(0xFF2563EB)
                          : (isCreditCardPurchase
                              ? AppTheme.secondaryColor
                              : Colors.red.shade700));

                  final sourceLabel = isCreditCardPayment
                      ? '${card?.name ?? 'Credit Card'} • From ${account?.name ?? 'Account'}'
                      : (isCreditCardPurchase
                          ? '${card?.name ?? 'Credit Card'} ****${card?.lastFourDigits ?? ''}'
                          : (account?.name ?? 'Account'));

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              iconData,
                              color: iconColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$sourceLabel • ${DateFormatter.format(tx.transactionDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$amountPrefix${CurrencyFormatter.format(tx.amount, currency: account?.currency ?? 'INR')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: amountColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
