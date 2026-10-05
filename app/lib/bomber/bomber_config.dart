import 'package:flutter/material.dart';

class BomberConfig {
  static const columns = 13, rows = 15;
  static const speed = 2.6, radius = .22;
  static const fuse = 2800,
      fire = 650,
      duration = 180000,
      reconnectGrace = 10000;
  static const networkInterval = 100,
      maxRange = 5,
      maxBombs = 3,
      maxSpeed = 1.5;
}

enum BomberCat { maru, lady, milo, nube }

extension BomberCatName on BomberCat {
  String get label => ['Maru', 'Lady', 'Milo', 'Nube'][index];
}

class BomberArena {
  final String name, subtitle;
  final Color background, floor, wall, crate, accent;
  const BomberArena(
    this.name,
    this.subtitle,
    this.background,
    this.floor,
    this.wall,
    this.crate,
    this.accent,
  );
}

const bomberArenas = [
  BomberArena(
    'Jardín de patitas',
    'Senderos y cajas entre flores',
    Color(0xff142d2b),
    Color(0xff598e73),
    Color(0xffadc4b8),
    Color(0xffce9968),
    Color(0xffffdc89),
  ),
  BomberArena(
    'Azotea lunar',
    'Pasillos abiertos bajo las estrellas',
    Color(0xff171c3a),
    Color(0xff596399),
    Color(0xffa2b4d1),
    Color(0xff9277b9),
    Color(0xff96e8ff),
  ),
  BomberArena(
    'Dulce despensa',
    'Un laberinto de galletas y premios',
    Color(0xff43223e),
    Color(0xffb27696),
    Color(0xfff0bcce),
    Color(0xffd3a076),
    Color(0xffffda82),
  ),
  BomberArena(
    'Templo del sol',
    'Pilares de piedra y caminos dorados',
    Color(0xff342416),
    Color(0xffb99056),
    Color(0xffe7c38a),
    Color(0xffa55f44),
    Color(0xffa9edc7),
  ),
];

enum KittenPower { yarn, tuna, fish, box, paw, cake }

extension KittenPowerLook on KittenPower {
  String get label => [
    'Ovillo de lana',
    'Lata de atún',
    'Pez de goma',
    'Caja de cartón',
    'Patita de la suerte',
    'La tortita',
  ][index];
  IconData get glyph => [
    Icons.sports_baseball_rounded,
    Icons.inventory_2_rounded,
    Icons.set_meal_rounded,
    Icons.all_inbox_rounded,
    Icons.pets_rounded,
    Icons.cake_rounded,
  ][index];
  String get effect => [
    '+1 alcance',
    '+1 bomba',
    '+15% velocidad',
    'Atraviesa cajas · 4 s',
    'Protege una vez',
    'Escudo · 5 s',
  ][index];
}
