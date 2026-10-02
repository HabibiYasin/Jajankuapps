import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';

class BudgetNotificationService {
  static const _channel = MethodChannel('com.jajanku.app/budget_notification');

  static Map<String, double> dailyTotals(List<TransactionModel> history) {
    final totals = <String, double>{};
    for (final tx in history) {
      final date = tx.dateTime.toLocal();
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      totals.update(
        key,
        (value) => value + tx.numericNominal,
        ifAbsent: () => tx.numericNominal,
      );
    }
    return totals;
  }

  static Future<void> sync(
    List<TransactionModel> history,
    double dailyLimit,
  ) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('sync', {
        'dailyLimit': dailyLimit,
        'totals': dailyTotals(history),
      });
    } on PlatformException catch (error) {
      debugPrint('Notifikasi budget gagal diperbarui: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Notifikasi budget belum tersedia: $error');
    }
  }
}
