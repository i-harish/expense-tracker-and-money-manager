import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/transactions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/services/financial_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/transaction_form_dialog.dart';

class TransactionsScreen extends StatefulWidget {
  final FinancialService? financialService;
  final AccountRepository? accountRepository;
  final CreditCardRepository? creditCardRepository;

  const TransactionsScreen({
    super.key,
    this.financialService,
    this.accountRepository,
    this.creditCardRepository,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final FinancialService _financialService;
  late final AccountRepository _accountRepository;
  late final CreditCardRepository _creditCardRepository;

  List<TransactionWithAccount> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance;
    _financialService =
        widget.financialService ?? DriftFinancialService(db);
    _accountRepository =
        widget.accountRepository ?? DriftAccountRepository(db);
    _creditCardRepository =
        widget.creditCardRepository ?? DriftCreditCardRepository(db);
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions =
          await _financialService.getTransactionsWithAccount();
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load transactions: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddTransactionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TransactionFormDialog(
        financialService: _financialService,
        accountRepository: _accountRepository,
        creditCardRepository: _creditCardRepository,
      ),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransactionDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTransactions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first income or expense.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openAddTransactionDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Transaction'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _transactions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _transactions[index];
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
          final amountColor =
              isIncome ? const Color(0xFF16A34A) : Colors.red.shade700;

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

          final iconData = isIncome
              ? Icons.arrow_upward
              : (isCreditCardPayment
                  ? Icons.payments_outlined
                  : (isCreditCardPurchase
                      ? Icons.credit_card_outlined
                      : Icons.arrow_downward));

          final sourceLabel = isCreditCardPayment
              ? '${card?.name ?? 'Credit Card'} • From ${account?.name ?? 'Account'}'
              : (isCreditCardPurchase
                  ? '${card?.name ?? 'Credit Card'} ****${card?.lastFourDigits ?? ''}'
                  : (account?.name ?? 'Account'));

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Transaction Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              sourceLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              DateFormatter.format(tx.transactionDate),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount
                  Text(
                    '$amountPrefix${CurrencyFormatter.format(tx.amount, currency: account?.currency ?? 'INR')}',
                    style: TextStyle(
                      fontSize: 16,
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
    );
  }
}

