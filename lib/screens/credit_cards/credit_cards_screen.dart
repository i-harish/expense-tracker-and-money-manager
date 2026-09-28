import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/credit_card_extensions.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../theme/app_theme.dart';
import 'widgets/credit_card_form_dialog.dart';
import 'widgets/credit_card_item_card.dart';

class CreditCardsScreen extends StatefulWidget {
  final CreditCardRepository? repository;

  const CreditCardsScreen({
    super.key,
    this.repository,
  });

  @override
  State<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends State<CreditCardsScreen> {
  late final CreditCardRepository _repository;
  List<CreditCard> _cards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        DriftCreditCardRepository(AppDatabase.instance);
    _loadCreditCards();
  }

  Future<void> _loadCreditCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cards = await _repository.getActiveCreditCards();
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load credit cards: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddCardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreditCardFormDialog(
        repository: _repository,
      ),
    );

    if (result == true) {
      _loadCreditCards();
    }
  }

  Future<void> _openEditCardDialog(CreditCard card) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreditCardFormDialog(
        card: card,
        repository: _repository,
      ),
    );

    if (result == true) {
      _loadCreditCards();
    }
  }

  Future<void> _confirmDeactivateCard(CreditCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Card'),
        content: Text(
          'Are you sure you want to deactivate "${card.name} (•••• ${card.lastFourDigits})"? It will no longer appear in your active credit cards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deactivateCreditCard(card.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credit card deactivated')),
          );
        }
        _loadCreditCards();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: _buildBody(),
      floatingActionButton: _cards.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openAddCardDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Card'),
              tooltip: 'Add Credit Card',
            )
          : null,
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
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadCreditCards,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCreditCards,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          _buildSummaryHeader(),
          const SizedBox(height: 20),
          const Text(
            'Active Cards',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final card = _cards[index];
              return CreditCardItemCard(
                card: card,
                onEdit: () => _openEditCardDialog(card),
                onDeactivate: () => _confirmDeactivateCard(card),
              );
            },
          ),
          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final totalOutstanding =
        _cards.fold<double>(0.0, (sum, card) => sum + card.outstandingBalance);
    final totalLimit =
        _cards.fold<double>(0.0, (sum, card) => sum + card.creditLimit);
    final totalAvailable =
        _cards.fold<double>(0.0, (sum, card) => sum + card.availableCredit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'TOTAL CREDIT LIABILITY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              CurrencyFormatter.format(totalOutstanding),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL LIMIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(totalLimit),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(totalAvailable),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_outlined,
                size: 64,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No credit cards yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first credit card to track your outstanding balance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openAddCardDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Credit Card'),
            ),
          ],
        ),
      ),
    );
  }
}
