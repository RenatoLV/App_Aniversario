import 'mz_catalog.dart';

class MzSpawn {
  const MzSpawn(this.time, this.row, this.kind, {this.shiny = false});
  final double time;
  final int row;
  final MzEnemy kind;
  final bool shiny;
}

class MzLevel {
  const MzLevel(this.id, {this.mode = MzMode.campaign, this.seed = 0});
  final int id, seed;
  final MzMode mode;
  MzWorld get world =>
      id >= 50 ? MzWorld.cemetery : MzWorld.values[(id ~/ 10).clamp(0, 4)];
  int get number => id % 10 + 1;
  bool get finale => number == 10;
  bool get boss => id == 49 && mode != MzMode.survival;
  String get title => '${world.title} · $number';
  int get startingCatnip => id == 0 ? 200 : 150;
  List<int> get rows => id == 0 ? [1, 2, 3] : [0, 1, 2, 3, 4];
  String get objective => id == 0
      ? 'Conserva al menos un Lanzador.'
      : 'No pierdas más de tres defensores.';
  List<MzCat> get allowed => mode == MzMode.challenge
      ? [
          MzCat.launcher,
          MzCat.sunflower,
          MzCat.barrier,
          MzCat.ice,
          MzCat.catapult,
          MzCat.values[7 + world.index.clamp(0, 3)],
        ]
      : mzUnlockedCats(world == MzWorld.cemetery ? 10 : id);
  List<MzEnemy> get enemies => [
    MzEnemy.common,
    if (id >= 2) MzEnemy.cone,
    if (id >= 6) MzEnemy.bucket,
    if (id >= 8) MzEnemy.flag,
    ...switch (world) {
      MzWorld.patio => <MzEnemy>[],
      MzWorld.cemetery => <MzEnemy>[],
      MzWorld.egypt => [
        MzEnemy.mummy,
        if (number >= 3) MzEnemy.pharaoh,
        if (number >= 5) MzEnemy.thief,
      ],
      MzWorld.pirates => [
        MzEnemy.corsair,
        if (number >= 3) MzEnemy.parrot,
        if (number >= 5) MzEnemy.cannon,
      ],
      MzWorld.west => [MzEnemy.pianist, if (number >= 3) MzEnemy.miner],
      MzWorld.future => [MzEnemy.mecha, if (number >= 3) MzEnemy.shield],
    },
    if (boss) MzEnemy.boss,
  ];

  // Explicit opening plus deterministic groups: each world introduces its
  // special invaders gradually, with a finite end and guaranteed tuna drops.
  List<MzSpawn> get spawns {
    final result = <MzSpawn>[];
    final count = id == 0
        ? 8
        : 14 + number * 2 + (world == MzWorld.cemetery ? 1 : world.index) * 3;
    final choices = enemies
        .where((e) => e != MzEnemy.boss && e != MzEnemy.flag)
        .toList();
    for (var i = 0; i < count; i++) {
      final row = rows[(i * 3 + seed + id) % rows.length];
      var kind = i < 3
          ? MzEnemy.common
          : choices[(i + seed + number) % choices.length];
      if (world == MzWorld.west && number >= 3) {
        if (kind == MzEnemy.miner) kind = MzEnemy.common;
        if (i == count ~/ 2 || (finale && i == count - 3)) kind = MzEnemy.miner;
      }
      result.add(
        MzSpawn(
          16 + i * (id == 0 ? 12.0 : 5.5),
          row,
          kind,
          shiny: id >= 7 && i % 9 == 4,
        ),
      );
    }
    final start = result.last.time + 14;
    if (id >= 8) {
      for (final row in rows) {
        result.add(MzSpawn(start, row, MzEnemy.flag));
        result.add(
          MzSpawn(
            start + 5,
            row,
            finale ? MzEnemy.bucket : MzEnemy.common,
            shiny: row == 2,
          ),
        );
      }
    }
    if (boss) result.add(MzSpawn(start + 10, 2, MzEnemy.boss));
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }
}

// IDs 0..49 are unchanged; cemetery IDs 50..59 are inserted chronologically.
final mzCampaign = [
  ...List.generate(10, MzLevel.new),
  ...List.generate(10, (i) => MzLevel(50 + i)),
  ...List.generate(40, (i) => MzLevel(10 + i)),
];

List<MzLevel> mzLevelsForWorld(MzWorld world) =>
    mzCampaign.where((l) => l.world == world).toList();
MzLevel? mzNextLevel(MzLevel level) {
  final index = mzCampaign.indexWhere((l) => l.id == level.id);
  return index < 0 || index == mzCampaign.length - 1
      ? null
      : mzCampaign[index + 1];
}

int mzCampaignNumber(int id) => mzCampaign.indexWhere((l) => l.id == id) + 1;
