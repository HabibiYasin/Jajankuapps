import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/spending_progress.dart';
import '../models/spending_card_style.dart';

/// Uses one shared layout for both the preview and exported PNG.
class SpendingCardRenderer {
  static Future<Uint8List> render(
    SpendingProgress data, {
    String username = 'Jajaners',
    int messageVariant = 0,
    bool hideAmounts = false,
    SpendingCardCharacter character = SpendingCardCharacter.jajanku,
    SpendingCardColor? cardColor,
  }) async {
    final mascotAsset =
        character.asset ??
        switch (data.artworkKey) {
          'ambyar' || 'duar' => 'assets/share/${data.artworkKey}_mascot.png',
          _ => 'assets/mascot/jajanku_mascot.png',
        };
    final asset = await rootBundle.load(mascotAsset);
    final codec = await ui.instantiateImageCodec(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    );
    final mascot = (await codec.getNextFrame()).image;
    codec.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(1080 / 941);
    const bounds = Rect.fromLTWH(0, 0, 941, 1672);
    final overspent = data.artworkKey == 'duar';
    final accent =
        cardColor?.accent ??
        (overspent ? const Color(0xFFE95A25) : const Color(0xFFEF861A));
    const ink = Color(0xFF65371F);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardColor != null
              ? [cardColor.top, cardColor.bottom]
              : overspent
              ? [
                  const Color(0xFFFFAC55),
                  const Color(0xFFF67D37),
                  const Color(0xFFED612C),
                ]
              : [
                  const Color(0xFFFFBC64),
                  const Color(0xFFFF9A34),
                  const Color(0xFFFF8228),
                ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      const Offset(915, 265),
      380,
      Paint()..color = Colors.white.withValues(alpha: 0.09),
    );
    canvas.drawCircle(
      const Offset(-90, 1330),
      390,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    void label(
      String value,
      Rect rect,
      double size, {
      Color color = ink,
      FontWeight weight = FontWeight.w600,
      TextAlign align = TextAlign.center,
      bool wrap = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: wrap ? rect.width : double.infinity);
      final scale = (rect.width / painter.width)
          .clamp(0.0, 1.0)
          .clamp(0.0, (rect.height / painter.height).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(
        align == TextAlign.left
            ? rect.left
            : rect.center.dx - painter.width * scale / 2,
        rect.center.dy - painter.height * scale / 2,
      );
      canvas.scale(scale);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      painter.dispose();
    }

    label(
      'Jajanku',
      const Rect.fromLTWH(80, 85, 600, 85),
      68,
      color: Colors.white,
      weight: FontWeight.w900,
      align: TextAlign.left,
    );
    label(
      data.period,
      const Rect.fromLTWH(80, 195, 780, 115),
      92,
      color: Colors.white,
      weight: FontWeight.w800,
      align: TextAlign.left,
    );
    label(
      data.dateLabel,
      const Rect.fromLTWH(80, 324, 510, 60),
      35,
      color: Colors.white,
      align: TextAlign.left,
    );
    final name = username.trim().replaceFirst(RegExp(r'^@+'), '').trim();
    const nameBounds = Rect.fromLTWH(80, 410, 390, 75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(nameBounds, const Radius.circular(24)),
      Paint()..color = cardColor?.tint ?? const Color(0xFFFFEDDA),
    );
    label(
      name.isEmpty ? 'Jajaners' : name,
      nameBounds.deflate(15),
      36,
      align: TextAlign.left,
    );
    label(
      switch (data.title) {
        'Hematers' => 'Jajan jalan,\ndompet santai.',
        'Strategist' => 'Jajan terukur,\nbudget teratur.',
        'Perfectionist' => 'Hampir pas,\ntetap terkendali.',
        'Ambyar' => 'Yuk, cek lagi\npengeluaranmu.',
        'Puasa atau lupa?' => 'Belum jajan,\natau belum dicatat?',
        _ => 'Atur budget,\nyuk mulai.',
      },
      const Rect.fromLTWH(80, 550, 310, 170),
      42,
      color: Colors.white,
      align: TextAlign.left,
      wrap: true,
    );

    const reportBounds = Rect.fromLTWH(62, 800, 817, 720);
    final reportShape = RRect.fromRectAndRadius(
      reportBounds,
      const Radius.circular(48),
    );
    canvas.drawShadow(
      Path()..addRRect(reportShape),
      cardColor?.accent ?? const Color(0xFFAE4E19),
      18,
      false,
    );
    canvas.drawRRect(reportShape, Paint()..color = const Color(0xFFFFFCF5));
    const mascotBounds = Rect.fromLTWH(300, 425, 580, 455);
    final sourceSize = Size(mascot.width.toDouble(), mascot.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, sourceSize, mascotBounds.size);
    canvas.drawImageRect(
      mascot,
      Alignment.center.inscribe(fitted.source, Offset.zero & sourceSize),
      Alignment.center.inscribe(fitted.destination, mascotBounds),
      Paint()..filterQuality = FilterQuality.high,
    );

    label(
      data.title,
      const Rect.fromLTWH(105, 890, 730, 85),
      68,
      color: accent,
      weight: FontWeight.w800,
    );
    final percent = data.percentage
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '')
        .replaceAll('.', ',');
    label(
      data.hasBudget ? '$percent%' : '-',
      const Rect.fromLTWH(105, 985, 730, 150),
      140,
      color: ink,
      weight: FontWeight.w900,
    );
    label(
      !data.hasBudget
          ? 'Atur budget untuk lihat progres'
          : data.monthly
          ? 'Budget bulanan terpakai'
          : 'Budget harian terpakai',
      const Rect.fromLTWH(105, 1145, 730, 48),
      32,
      color: const Color(0xFF9C765E),
    );
    label(
      data.amountLabel(hideAmounts: hideAmounts),
      const Rect.fromLTWH(105, 1210, 730, 60),
      38,
    );
    const bar = Rect.fromLTWH(112, 1295, 717, 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(11)),
      Paint()..color = cardColor?.tint ?? const Color(0xFFFFE8D1),
    );
    final fraction = (data.percentage / 100).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bar.left, bar.top, bar.width * fraction, bar.height),
          const Radius.circular(11),
        ),
        Paint()..color = accent,
      );
    }
    label(
      data.messageForVariant(messageVariant),
      const Rect.fromLTWH(112, 1360, 717, 108),
      33,
      wrap: true,
    );
    label(
      data.comparisonLabel(hideAmounts: hideAmounts) ??
          'Catat jajan, lebih tenang.',
      const Rect.fromLTWH(80, 1545, 781, 95),
      30,
      color: Colors.white,
      wrap: true,
    );

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(1080, 1920);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Gambar gagal dibuat');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      mascot.dispose();
      picture.dispose();
    }
  }
}
