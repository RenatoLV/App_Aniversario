import 'mz_catalog.dart';

Map<String, dynamic> mzMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
double mzNum(Map<String, dynamic> j, String key, [double fallback = 0]) =>
    (j[key] as num?)?.toDouble() ?? fallback;

class MzDefender {
  MzDefender(this.id, this.kind, this.row, this.col)
    : hp = mzCats[kind]!.hp,
      attack = kind == MzCat.sunflower ? 8 : .4;
  final int id;
  final MzCat kind;
  int row, col;
  double hp, armor = 0, age = 0, attack, powerUntil = 0, burst = 0;
  int burstLeft = 0;
  bool get armed => kind == MzCat.mine && age >= 8;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'row': row,
    'col': col,
    'hp': hp,
    'armor': armor,
    'age': age,
    'attack': attack,
    'power': powerUntil,
    'burst': burst,
    'left': burstLeft,
  };
  factory MzDefender.fromJson(Map<String, dynamic> j) =>
      MzDefender(
          j['id'] as int,
          MzCat.values[j['kind'] as int],
          j['row'] as int,
          j['col'] as int,
        )
        ..hp = mzNum(j, 'hp')
        ..armor = mzNum(j, 'armor')
        ..age = mzNum(j, 'age')
        ..attack = mzNum(j, 'attack')
        ..powerUntil = mzNum(j, 'power')
        ..burst = mzNum(j, 'burst')
        ..burstLeft = j['left'] as int;
}

class MzInvader {
  MzInvader(this.id, this.kind, this.row, {this.x = 9.6, this.shiny = false})
    : hp = kind.health,
      armor = kind.protection;
  final int id;
  final MzEnemy kind;
  int row;
  double x,
      hp,
      armor,
      attack = 0,
      special = 12,
      slowUntil = 0,
      frozenUntil = 0,
      immuneUntil = 0;
  bool shiny;
  double lureUntil = 0, lureX = 0;
  int? captive;
  bool get alive => hp > 0;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'row': row,
    'x': x,
    'hp': hp,
    'armor': armor,
    'attack': attack,
    'special': special,
    'slow': slowUntil,
    'frozen': frozenUntil,
    'immune': immuneUntil,
    'shiny': shiny,
    'captive': captive,
    'lureUntil': lureUntil,
    'lureX': lureX,
  };
  factory MzInvader.fromJson(Map<String, dynamic> j) =>
      MzInvader(
          j['id'] as int,
          MzEnemy.values[j['kind'] as int],
          j['row'] as int,
          x: mzNum(j, 'x'),
          shiny: j['shiny'] == true,
        )
        ..hp = mzNum(j, 'hp')
        ..armor = mzNum(j, 'armor')
        ..attack = mzNum(j, 'attack')
        ..special = mzNum(j, 'special')
        ..slowUntil = mzNum(j, 'slow')
        ..frozenUntil = mzNum(j, 'frozen')
        ..immuneUntil = mzNum(j, 'immune')
        ..lureUntil = mzNum(j, 'lureUntil')
        ..lureX = mzNum(j, 'lureX')
        ..captive = j['captive'] as int?;
}

class MzProjectile {
  MzProjectile(
    this.id,
    this.row,
    this.x,
    this.damage, {
    this.ice = false,
    this.target,
    this.arc = false,
  }) : origin = x;
  final int id, row;
  double x, damage;
  bool ice, arc;
  bool fish = false, returning = false;
  double origin;
  final outboundHits = <int>{}, inboundHits = <int>{};
  int? target;
  Map<String, dynamic> toJson() => {
    'id': id,
    'row': row,
    'x': x,
    'damage': damage,
    'ice': ice,
    'arc': arc,
    'target': target,
    'fish': fish,
    'returning': returning,
    'origin': origin,
    'outbound': outboundHits.toList(),
    'inbound': inboundHits.toList(),
  };
  factory MzProjectile.fromJson(Map<String, dynamic> j) =>
      MzProjectile(
          j['id'] as int,
          j['row'] as int,
          mzNum(j, 'x'),
          mzNum(j, 'damage'),
          ice: j['ice'] == true,
          arc: j['arc'] == true,
          target: j['target'] as int?,
        )
        ..fish = j['fish'] == true
        ..returning = j['returning'] == true
        ..origin = mzNum(j, 'origin')
        ..outboundHits.addAll(((j['outbound'] as List?) ?? []).cast<int>())
        ..inboundHits.addAll(((j['inbound'] as List?) ?? []).cast<int>());
}

class MzPickup {
  MzPickup(this.id, this.row, this.x, {this.tuna = false, this.ttl = 10});
  final int id, row;
  final double x;
  final bool tuna;
  double ttl;
  Map<String, dynamic> toJson() => {
    'id': id,
    'row': row,
    'x': x,
    'tuna': tuna,
    'ttl': ttl,
  };
  factory MzPickup.fromJson(Map<String, dynamic> j) => MzPickup(
    j['id'] as int,
    j['row'] as int,
    mzNum(j, 'x'),
    tuna: j['tuna'] == true,
    ttl: mzNum(j, 'ttl'),
  );
}

class MzEffect {
  MzEffect(this.row, this.x, this.type, {this.ttl = .5});
  final int row;
  final double x;
  final String type;
  double ttl;
}

class MzWarning {
  MzWarning(this.row, this.col, this.type, this.at);
  final int row, col;
  final String type;
  final double at;
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'type': type,
    'at': at,
  };
  factory MzWarning.fromJson(Map<String, dynamic> j) => MzWarning(
    j['row'] as int,
    j['col'] as int,
    j['type'] as String,
    mzNum(j, 'at'),
  );
}
