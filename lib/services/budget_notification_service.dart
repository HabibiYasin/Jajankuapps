import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';

class BudgetNotificationService {
  static const _channel = MethodChannel('com.jajanku.app/budget_notification');
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('getEnabled') ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }

  static Future<bool> isNoonEnabled() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('getNoonEnabled') ?? true;
  }

  static Future<void> setNoonEnabled(bool enabled) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('setNoonEnabled', {'enabled': enabled});
  }

  static Map<String, double> dailyTotals(List<TransactionModel> history) {
    final totals = <String, double>{};
    for (final tx in history) {
      if (tx.isIncome) continue;
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
    if (!isSupported) return;
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
