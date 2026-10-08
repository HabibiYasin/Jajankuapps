import 'package:flutter/material.dart';

enum SpendingCardCharacter {
  jajanku('Jajanku', null),
  esDoger('Es Doger', 'assets/mascot/es_doger.png'),
  esTeh('Es Teh', 'assets/mascot/es_teh.png'),
  seblak('Seblak', 'assets/mascot/seblak.png'),
  boba('Boba', 'assets/mascot/boba.png'),
  bakso('Bakso', 'assets/mascot/bakso.png'),
  cilok('Cilok', 'assets/mascot/cilok.png');

  const SpendingCardCharacter(this.label, this.asset);
  final String label;
  final String? asset;
}

enum SpendingCardColor {
  orange('Oranye', Color(0xFFEF861A), Color(0xFFFFBC64), Color(0xFFFF8228)),
  turquoise(
    'Turquoise',
    Color(0xFF00897B),
    Color(0xFF32C8BA),
    Color(0xFF007E79),
  ),
  blue('Biru', Color(0xFF2563B8), Color(0xFF65AAF0), Color(0xFF2859AD)),
  purple('Ungu', Color(0xFF7949BC), Color(0xFFB18AE0), Color(0xFF7042AB)),
  pink('Pink', Color(0xFFC43D79), Color(0xFFF18FB6), Color(0xFFBC3970)),
  green('Hijau', Color(0xFF32844D), Color(0xFF83C88A), Color(0xFF30794C));

  const SpendingCardColor(this.label, this.accent, this.top, this.bottom);
  final String label;
  final Color accent;
  final Color top;
  final Color bottom;

  Color get tint => Color.lerp(Colors.white, accent, 0.12)!;
}
