import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/spending_progress.dart';
import 'package:flutter_application_1/services/spending_card_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SpendingProgress progress(double spent, {double budget = 100}) =>
      SpendingProgress(
        period: 'Kemarin',
        date: DateTime(2026, 9, 30),
        spent: spent,
        budget: budget,
      );

  test('Titles use inclusive budget thresholds without rounding the ratio', () {
    for (final (spent, title) in [
      (0.0, 'Puasa atau lupa?'),
      (0.01, 'Hematers'),
      (50.0, 'Hematers'),
      (50.01, 'Strategist'),
      (75.0, 'Strategist'),
      (75.01, 'Perfectionist'),
      (100.0, 'Perfectionist'),
      (100.01, 'Ambyar'),
      (200.0, 'Ambyar'),
    ]) {
      expect(progress(spent).title, title);
    }
    expect(progress(10, budget: 0).hasBudget, isFalse);
    expect(progress(10, budget: 0).title, 'Belum Ada Budget');
    expect(progress(0).dateLabel, '30 September 2026');
    expect(SpendingProgress.rupiah(1500000), 'Rp 1.500.000');
  });

  test('Comparison handles savings, overspending and a zero baseline', () {
    SpendingProgress compare(
      double spent,
      double previous, {
      bool monthly = false,
    }) => SpendingProgress(
      period: 'Hari Ini',
      date: DateTime(2026, 10, 6),
      spent: spent,
      budget: 100,
      previousSpent: previous,
      monthly: monthly,
    );
    expect(compare(85, 100).comparison, 'Lebih hemat 15% dari hari kemarin');
    expect(
      compare(140, 100, monthly: true).comparison,
      'Lebih boros 40% dari bulan kemarin',
    );
    expect(compare(100, 100).comparison, 'Sama dengan hari kemarin');
    expect(compare(0, 100).comparison, 'Lebih hemat 100% dari hari kemarin');
    expect(
      compare(10, 0).comparison,
      'Belum ada pengeluaran hari kemarin untuk dibandingkan',
    );
    expect(compare(99.9, 100).comparison, 'Lebih hemat <1% dari hari kemarin');
    expect(progress(10).comparison, isNull);
    expect(progress(25).amountLabel(hideAmounts: true), 'XX / XX');
    expect(progress(25).amountLabel(), 'Rp 25 / Rp 100');
  });

  test('Each title provides five distinct messages and its own artwork', () {
    final assets = <String>{};
    for (final spent in [0.0, 25.0, 60.0, 90.0, 150.0]) {
      final data = progress(spent);
      expect(data.messages.toSet().length, 5);
      assets.add(data.artworkAsset);
      for (var variant = 0; variant < 5; variant++) {
        expect(data.messageForVariant(variant), data.messages[variant]);
      }
      expect(data.messageForVariant(5), data.messages.first);
    }
    expect(assets.length, 5);
  });

  test(
    'Exports portrait PNG including overspending and zero-budget cases',
    () async {
      for (final data in [
        progress(0),
        progress(25),
        progress(60),
        progress(90),
        progress(150),
        progress(0, budget: 0),
      ]) {
        final bytes = await SpendingCardRenderer.render(
          data,
          hideAmounts: true,
        );
        final visible = await SpendingCardRenderer.render(data);
        expect(bytes, isNot(orderedEquals(visible)));
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, 1920);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
