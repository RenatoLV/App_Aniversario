// Isolated art workshop: no Firebase, preferences, wallet or audio initialization.
import 'package:flutter/material.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: const LuckyPalaceScreen(),
  ),
);
