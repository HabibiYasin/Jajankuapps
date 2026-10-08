import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import 'transaction_history_screen.dart';

class IncomeScreen extends StatelessWidget {
  final bool isPremium;
  final List<TransactionModel> history;
  final Future<void> Function() onAddIncome;
  final Function(TransactionModel) onDelete;
  final Function(TransactionModel, DateTime) onUpdateDate;
  final Function(TransactionModel) onUpdateTransaction;

  const IncomeScreen({
    super.key,
    this.isPremium = false,
    required this.history,
    required this.onAddIncome,
    required this.onDelete,
    required this.onUpdateDate,
    required this.onUpdateTransaction,
  });

  @override
  Widget build(BuildContext context) => TransactionHistoryScreen(
    isPremium: isPremium,
    history: history,
    incomeOnly: true,
    onAddIncome: onAddIncome,
    onDelete: onDelete,
    onUpdateDate: onUpdateDate,
    onUpdateTransaction: onUpdateTransaction,
  );
}
