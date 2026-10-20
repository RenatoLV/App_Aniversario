import 'package:flutter/material.dart';

/// Local art direction; does not alter the application's shared theme.
abstract final class LuckyPalette {
  static const night = Color(0xff120f26);
  static const velvet = Color(0xff452047);
  static const enamel = Color(0xff86254f);
  static const ink = Color(0xff442237);
  static const cream = Color(0xfffff0d4);
  static const goldLight = Color(0xffffedaf);
  static const gold = Color(0xffe6af50);
  static const goldDark = Color(0xff89502c);
  static const mint = Color(0xff63e0d3);
  static const pink = Color(0xffef7ea8);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark, gold, goldLight],
    stops: [0, .36, .59, .8, 1],
  );

  static TextStyle text(
    double size, {
    Color color = cream,
    bool title = false,
  }) => TextStyle(
    fontFamily: title ? 'Fredoka' : 'Nunito',
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
  );
}
