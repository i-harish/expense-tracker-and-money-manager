import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/accounts.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/account_repository.dart';
import '../../theme/app_theme.dart';
import 'widgets/account_form_dialog.dart';

class AccountsScreen extends StatefulWidget {
  final AccountRepository? accountRepository;

  const AccountsScreen({
    super.key,
    this.accountRepository,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final AccountRepository _repository;
  List<Account> _accounts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.accountRepository ?? DriftAccountRepository(AppDatabase.instance);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _repository.getActiveAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load accounts: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddAccountDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AccountFormDialog(
        repository: _repository,
      ),
    );

    if (result == true) {
      _loadAccounts();
    }
  }

  Future<void> _openEditAccountDialog(Account account) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AccountFormDialog(
        account: account,
        repository: _repository,
      ),
    );

    if (result == true) {
      _loadAccounts();
    }
  }

  Future<void> _confirmDeactivateAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Account'),
        content: Text(
          'Are you sure you want to deactivate "${account.name}"? It will no longer appear in your active accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deactivateAccount(account.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account "${account.name}" deactivated'),
            ),
          );
          _loadAccounts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to deactivate: ${e.toString()}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.savings:
        return Icons.savings;
      case AccountType.cash:
        return Icons.payments;
    }
  }

  Color _getAccountColor(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return AppTheme.primaryColor;
      case AccountType.savings:
        return AppTheme.secondaryColor;
      case AccountType.cash:
        return const Color(0xFF16A34A);
    }
  }

  String _getAccountTypeName(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 'Bank';
      case AccountType.savings:
        return 'Savings';
      case AccountType.cash:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAccountDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
                onPressed: _loadAccounts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAccounts,
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
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No accounts yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first bank, savings, or cash account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openAddAccountDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _accounts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final account = _accounts[index];
          final color = _getAccountColor(account.type);
          final typeName = _getAccountTypeName(account.type);

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openEditAccountDialog(account),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Account Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getAccountIcon(account.type),
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Account Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              typeName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Balance & Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(account.balance,
                              currency: account.currency),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: AppTheme.textSecondary,
                              tooltip: 'Edit',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _openEditAccountDialog(account),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red.shade400),
                              tooltip: 'Deactivate',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _confirmDeactivateAccount(account),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
