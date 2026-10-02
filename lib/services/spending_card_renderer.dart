import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/spending_progress.dart';

/// Uses the supplied artwork for both the preview and exported PNG.
class SpendingCardRenderer {
  static Future<Uint8List> render(
    SpendingProgress data, {
    String username = 'Jajaners',
  }) async {
    final asset = await rootBundle.load('assets/share/spending_progress.png');
    final codec = await ui.instantiateImageCodec(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    );
    final background = (await codec.getNextFrame()).image;
    codec.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(1080 / 941);
    const orange = Color(0xFFFF5100);
    const bounds = Rect.fromLTWH(0, 0, 941, 1672);
    canvas.drawImageRect(
      background,
      Rect.fromLTWH(
        0,
        0,
        background.width.toDouble(),
        background.height.toDouble(),
      ),
      bounds,
      Paint(),
    );

    void text(
      String value,
      Rect rect,
      double fontSize, {
      FontWeight weight = FontWeight.w600,
      Color color = orange,
      bool multiline = false,
      TextAlign align = TextAlign.center,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: multiline ? rect.width : double.infinity);
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

    void panel(Rect rect, double radius, List<Color> colors) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..shader = LinearGradient(colors: colors).createShader(rect),
      );
    }

    // Replace every example placeholder while retaining the mascot and artwork.
    const heading = Rect.fromLTWH(55, 247, 530, 128);
    if (data.period != 'Kemarin') {
      canvas.drawRect(
        heading,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6908), Color(0xFFFF7510), Color(0xFFFF5910)],
          ).createShader(heading),
      );
      text(
        data.period,
        heading.deflate(5),
        118,
        weight: FontWeight.w900,
        color: Colors.white,
        align: TextAlign.left,
      );
    }

    void pill(Rect rect, IconData icon, String value) {
      panel(rect, 42, [const Color(0xFFFFE9C9), const Color(0xFFFFD5A9)]);
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 46,
            color: orange,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(rect.left + 30, rect.center.dy - painter.height / 2),
      );
      painter.dispose();
      text(
        value,
        Rect.fromLTWH(
          rect.left + 105,
          rect.top + 8,
          rect.width - 130,
          rect.height - 16,
        ),
        40,
        align: TextAlign.left,
      );
    }

    pill(
      const Rect.fromLTWH(70, 395, 446, 74),
      Icons.calendar_month_rounded,
      data.dateLabel,
    );
    final name = username.trim().replaceFirst(RegExp(r'^@+'), '');
    pill(
      const Rect.fromLTWH(70, 483, 437, 75),
      Icons.person_rounded,
      '@${name.isEmpty ? 'Jajaners' : name}',
    );

    // Start below the mascot's paws so they remain visible over the card.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(53, 570, 836, 700),
        const Radius.circular(62),
      ),
    );
    panel(const Rect.fromLTWH(53, 609, 836, 661), 0, [
      const Color(0xFFFFFEFC),
      Colors.white,
      const Color(0xFFFFFCF5),
    ]);
    canvas.drawCircle(
      const Offset(471, 925),
      334,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 62
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFDFBC), Color(0x18FFF2E1)],
        ).createShader(const Rect.fromLTWH(106, 591, 730, 730)),
    );
    text(
      data.hasBudget
          ? '${data.percentage.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'
          : 'â€”',
      const Rect.fromLTWH(104, 743, 733, 165),
      148,
      weight: FontWeight.w900,
    );
    text(
      data.title,
      const Rect.fromLTWH(106, 940, 730, 101),
      82,
      weight: FontWeight.w900,
    );
    text(
      '${SpendingProgress.rupiah(data.spent)} / ${SpendingProgress.rupiah(data.budget)}',
      const Rect.fromLTWH(112, 1074, 718, 61),
      40,
      color: const Color(0xFF32120A),
    );
    const bar = Rect.fromLTWH(108, 1153, 725, 55);
    panel(bar, 30, [const Color(0xFFFFE6CB), const Color(0xFFFFDDC0)]);
    final fraction = (data.percentage / 100).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(bar, const Radius.circular(30)));
      panel(
        Rect.fromLTWH(bar.left, bar.top, bar.width * fraction, bar.height),
        30,
        [const Color(0xFFFFAD00), orange],
      );
      canvas.restore();
    }
    canvas.restore();
    const messageBox = Rect.fromLTWH(59, 1291, 823, 170);
    panel(messageBox, 50, [
      const Color(0xFFFFE9CD),
      const Color(0xFFFFFCF6),
      const Color(0xFFFFE9CC),
    ]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(messageBox, const Radius.circular(50)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    text(data.message, messageBox.deflate(30), 36, multiline: true);
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
      background.dispose();
      picture.dispose();
    }
  }
}
