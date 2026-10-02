import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/spending_progress.dart';

/// Draws the preview and exported PNG from the same fixed portrait layout.
class SpendingCardRenderer {
  static Future<Uint8List> render(SpendingProgress data) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    const size = Size(540, 960);
    const green = Color(0xFF105438);
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE2F2DF), Color(0xFFFDFFFC), Color(0xFFDDEEDD)],
        ).createShader(bounds),
    );
    for (final (center, radius) in [
      (const Offset(-85, 5), 210.0),
      (const Offset(540, -20), 140.0),
      (const Offset(-75, 965), 220.0),
      (const Offset(500, 1020), 220.0),
      (const Offset(575, 580), 110.0),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xAA75B980), Color(0x447DD071)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    void text(
      String value,
      double y,
      double fontSize, {
      FontWeight weight = FontWeight.w400,
      Color color = green,
      double width = 450,
      bool multiline = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: multiline ? width : double.infinity);
      canvas.save();
      final scale = multiline
          ? (fontSize * 2.5 / painter.height).clamp(0.0, 1.0)
          : (width / painter.width).clamp(0.0, 1.0);
      canvas.translate((540 - painter.width * scale) / 2, y);
      canvas.scale(scale);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    RRect box(Rect rect, double radius, Color color) {
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(shape, Paint()..color = color);
      return shape;
    }

    text('Jajanku', 62, 36, weight: FontWeight.w900);
    text(data.period, 137, 60, weight: FontWeight.w900);
    box(const Rect.fromLTWH(118, 222, 304, 42), 25, const Color(0xBBDFF0DF));
    text(data.dateLabel, 232, 21, width: 290);
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(35, 285, 470, 410),
      const Radius.circular(38),
    );
    canvas.drawShadow(
      Path()..addRRect(panel),
      const Color(0x3371A36C),
      18,
      true,
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xEEFFFFFF));
    canvas.drawArc(
      const Rect.fromLTWH(95, 325, 350, 350),
      2.5,
      4.3,
      false,
      Paint()
        ..color = const Color(0x227ACC59)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25,
    );
    text(
      data.hasBudget
          ? '${data.percentage.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'
          : '—',
      391,
      78,
      weight: FontWeight.w900,
    );
    text(data.title, 501, 42, weight: FontWeight.w900);
    text(
      '${SpendingProgress.rupiah(data.spent)} / ${SpendingProgress.rupiah(data.budget)}',
      585,
      24,
      color: const Color(0xFF393D40),
    );
    const bar = Rect.fromLTWH(65, 636, 410, 30);
    box(bar, 20, const Color(0xFFDCEBDC));
    final fraction = (data.percentage / 100).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(bar, const Radius.circular(20)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(65, 636, 410 * fraction, 30),
          const Radius.circular(20),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF9AD973), Color(0xFF29956C)],
          ).createShader(bar),
      );
      canvas.restore();
    }
    final messageBox = box(
      const Rect.fromLTWH(40, 708, 460, 96),
      30,
      const Color(0xBBDFF0D0),
    );
    canvas.drawRRect(
      messageBox,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    text(data.message, 731, 23, width: 410, multiline: true);
    text(
      'Bagikan progres pengeluaranmu bareng Jajanku',
      847,
      15,
      color: const Color(0xFF697779),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 1920);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Gambar gagal dibuat');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
