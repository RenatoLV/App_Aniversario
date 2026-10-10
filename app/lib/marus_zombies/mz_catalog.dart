enum MzCat {
  launcher,
  sunflower,
  barrier,
  ice,
  mine,
  bomb,
  catapult,
  boomerang,
  spring,
  lightning,
  laser,
}

enum MzEnemy {
  common,
  cone,
  bucket,
  flag,
  mummy,
  pharaoh,
  thief,
  corsair,
  parrot,
  cannon,
  pianist,
  miner,
  mecha,
  shield,
  boss,
}

// Append new worlds so persisted indices and existing reward claims stay valid.
enum MzWorld { patio, egypt, pirates, west, future, cemetery }

const mzWorldOrder = [
  MzWorld.patio,
  MzWorld.cemetery,
  MzWorld.egypt,
  MzWorld.pirates,
  MzWorld.west,
  MzWorld.future,
];

enum MzPower { pinch, pointer, spray }

enum MzMode { campaign, challenge, survival }

class MzCatSpec {
  const MzCatSpec(
    this.name,
    this.cost,
    this.cooldown,
    this.hp,
    this.damage,
    this.interval,
    this.description,
    this.tuna,
  );
  final String name, description, tuna;
  final int cost;
  final double cooldown, hp, damage, interval;
}

const mzCats = <MzCat, MzCatSpec>{
  MzCat.launcher: MzCatSpec(
    'Lanzador',
    100,
    5,
    300,
    20,
    1.4,
    'Ovillos verdes por su carril.',
    '60 ovillos en un segundo.',
  ),
  MzCat.sunflower: MzCatSpec(
    'Girasol',
    50,
    5,
    300,
    0,
    24,
    'Genera 25 de hierba cada 24 s.',
    '15 burbujas de hierba.',
  ),
  MzCat.barrier: MzCatSpec(
    'Maru Wuatón',
    50,
    15,
    3000,
    0,
    0,
    'Barrera: un chonker con 3.000 de resistencia.',
    'Recupera vida y gana armadura.',
  ),
  MzCat.ice: MzCatSpec(
    'Siberiano',
    175,
    8,
    300,
    20,
    1.8,
    'Ralentiza movimiento y mordidas.',
    'Ventisca que congela el carril.',
  ),
  MzCat.mine: MzCatSpec(
    'Caja sorpresa',
    25,
    15,
    300,
    1200,
    8,
    'Se arma en 8 s; salta al contacto.',
    'Se arma y crea dos cajas.',
  ),
  MzCat.bomb: MzCatSpec(
    'Gatitos bomba',
    150,
    30,
    300,
    1200,
    .8,
    'Explosión de pelusa en área 3×3.',
    'Explota automáticamente.',
  ),
  MzCat.catapult: MzCatSpec(
    'Catapulta',
    125,
    7,
    300,
    35,
    2.2,
    'Croquetas que saltan las tumbas.',
    'Croquetas para doce invasores.',
  ),
  MzCat.boomerang: MzCatSpec(
    'Bumerán',
    175,
    8,
    300,
    20,
    2,
    'Pez que golpea hasta tres enemigos dos veces.',
    'Tres peces reforzados.',
  ),
  MzCat.spring: MzCatSpec(
    'Resorte',
    75,
    12,
    300,
    0,
    5,
    'Empuja enemigos; ideal junto al agua.',
    'Gran empujón de tres casillas.',
  ),
  MzCat.lightning: MzCatSpec(
    'Relámpago',
    150,
    7,
    300,
    15,
    1.5,
    'Rayos encadenados entre filas.',
    'Descarga sobre ocho enemigos.',
  ),
  MzCat.laser: MzCatSpec(
    'Láser',
    225,
    10,
    300,
    30,
    0,
    'Haz que atraviesa el carril y escudos.',
    'Láser reforzado durante 3 s.',
  ),
};

extension MzEnemyStats on MzEnemy {
  String get label => const [
    'Zombimaru',
    'Cono Wuatón',
    'Lady Gordota',
    'Maru Banderón',
    'Marumomia',
    'Faraón Wuatón',
    'Lady Robatún',
    'Lady Piratona',
    'Lady Aladota',
    'Maru Cañontrón',
    'Maru Pianotrón',
    'Lady Topota',
    'Maru Locotrón',
    'Wuatón Blindado',
    'Dr. Maru Cat-trófico',
  ][index];

  /// Nicknames are presentation only; the role keeps each archetype identifiable.
  String get role => const [
    'Gato zombi',
    'Cono veterinario',
    'Balde oxidado',
    'Abanderado',
    'Momia',
    'Faraón',
    'Ladrón de tumbas',
    'Corsario',
    'Loro zombi',
    'Cañón de huesos',
    'Pianista',
    'Minero',
    'Mecha-gato',
    'Perro escudo',
    'Dr. Cat-trófico',
  ][index];
  double get health => this == MzEnemy.boss
      ? 12000
      : this == MzEnemy.flag
      ? 260
      : this == MzEnemy.mecha
      ? 500
      : 200;
  double get protection => switch (this) {
    MzEnemy.cone => 200,
    MzEnemy.bucket => 600,
    MzEnemy.pharaoh => 900,
    MzEnemy.shield => 450,
    _ => 0,
  };
  double get speed => switch (this) {
    MzEnemy.parrot => .32,
    MzEnemy.thief => .23,
    MzEnemy.flag => .18,
    MzEnemy.bucket || MzEnemy.pharaoh || MzEnemy.mecha => .12,
    MzEnemy.boss => 0,
    _ => .15,
  };
  bool get elite =>
      protection > 0 || this == MzEnemy.mecha || this == MzEnemy.boss;
}

extension MzWorldInfo on MzWorld {
  String get title => const [
    'Patio de Maru',
    'Reino del Gato Faraón',
    'Barco del Perro Pirata',
    'Saloon de los Gatos Callejeros',
    'Cyber-Gatos 2099',
    'Cementerio de los Michis',
  ][index];
  String get rule => const [
    'Protege la casa con hierba, ovillos y cinco Roombas.',
    'Defiende el templo entre pirámides y palmeras.',
    'No plantes en agua. Los resortes empujan invasores al mar.',
    'Toca un carrito y luego su destino en la vía para mover al gato.',
    'Dar atún a un nodo activa todos los gatos de su símbolo.',
    'Las lápidas bloquean ovillos. Usa catapultas o rompe la piedra bajo la luna.',
  ][index];
}

extension MzPowerInfo on MzPower {
  String get label =>
      const ['Pellizco', 'Puntero láser', 'Spray de agua'][index];
  int get cost => const [50, 75, 100][index];
}

List<MzCat> mzUnlockedCats(int highest) => MzCat.values
    .where(
      (cat) =>
          highest >= const [0, 1, 2, 3, 4, 5, 6, 10, 20, 30, 40][cat.index],
    )
    .toList();
