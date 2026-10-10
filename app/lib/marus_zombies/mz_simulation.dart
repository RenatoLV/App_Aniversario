import 'dart:math' as math;
import 'mz_catalog.dart';
import 'mz_levels.dart';
import 'mz_models.dart';

/// Fixed-step combat in board coordinates. Rendering never applies damage.
class MzSimulation {
  MzSimulation(this.level, {List<MzCat>? deck})
    : deck = deck ?? level.allowed.take(6).toList(),
      catnip = level.startingCatnip {
    rng = (level.seed + level.id * 7919 + 42) & 0x7fffffff;
    if (level.world == MzWorld.cemetery) {
      for (final row in [0, 2, 4]) {
        tombs[row * 9 + 5 + row % 2] = 220;
      }
    }
    if (level.world == MzWorld.pirates) bridges.addAll([15, 33]);
    if (level.world == MzWorld.west) carts.addAll([1, 19, 37]);
  }
  static const version = 1, step = 1 / 60;
  final MzLevel level;
  late final List<MzSpawn> schedule = level.spawns;
  final List<MzCat> deck;
  final defenders = <MzDefender>[], captives = <MzDefender>[];
  final invaders = <MzInvader>[];
  final projectiles = <MzProjectile>[];
  final pickups = <MzPickup>[];
  final effects = <MzEffect>[];
  final warnings = <MzWarning>[];
  final tombs = <int, double>{};
  final bridges = <int>{}, carts = <int>{};
  final cooldowns = <MzCat, double>{};
  final roombas = List<bool>.filled(5, true);
  final roombaX = List<double>.filled(5, -2);
  int catnip,
      tuna = 0,
      nextId = 1,
      spawnIndex = 0,
      rng = 42,
      losses = 0,
      kills = 0,
      wave = 0,
      bossAdds = 0;
  double time = 0,
      accumulator = 0,
      sky = 3,
      worldTimer = 30,
      humanUntil = 0,
      lionUntil = 0,
      survivalAt = 20;
  bool won = false,
      lost = false,
      lionUsed = false,
      boughtTuna = false,
      paused = false,
      autoCollect = false;
  String notice = 'Selecciona un gato y toca una casilla.';
  double noticeUntil = 8;
  bool get ended => won || lost;
  int get stars => !won
      ? 0
      : 1 +
            (roombas.every((v) => v) ? 1 : 0) +
            (level.id == 0
                ? (defenders.any((d) => d.kind == MzCat.launcher) ? 1 : 0)
                : (losses <= 3 ? 1 : 0));
  double get progress => level.mode == MzMode.survival
      ? (time % 30) / 30
      : (spawnIndex / schedule.length).clamp(0, 1);
  int random(int max) {
    // Product stays below 2^53 on web, so seeds agree with native Dart.
    rng = (rng * 1664525 + 1013904223) & 0x7fffffff;
    return rng % max;
  }

  bool validCell(int row, int col) =>
      row >= 0 && row < 5 && col >= 0 && col < 9 && level.rows.contains(row);
  bool water(int row, int col) =>
      level.world == MzWorld.pirates &&
      (row == 1 || row == 3) &&
      col == 6 &&
      !bridges.contains(row * 9 + col);
  MzDefender? at(int row, int col) {
    for (final d in defenders) {
      if (d.row == row && d.col == col && d.hp > 0) return d;
    }
    return null;
  }

  bool free(int row, int col) =>
      validCell(row, col) &&
      !water(row, col) &&
      !tombs.containsKey(row * 9 + col) &&
      at(row, col) == null;
  void say(String text, [double seconds = 3]) {
    notice = text;
    noticeUntil = time + seconds;
  }

  bool place(MzCat kind, int row, int col) {
    if (ended || paused) return false;
    final spec = mzCats[kind]!;
    if (!deck.contains(kind) || !free(row, col)) {
      say('Esa casilla no está libre.');
      return false;
    }
    if (catnip < spec.cost) {
      say('Necesitas más hierba gatera.');
      return false;
    }
    if ((cooldowns[kind] ?? 0) > time) {
      say('La tarjeta todavía está recargando.');
      return false;
    }
    catnip -= spec.cost;
    cooldowns[kind] = time + spec.cooldown;
    defenders.add(MzDefender(nextId++, kind, row, col));
    effect(row, col + .5, 'place');
    return true;
  }

  bool remove(int row, int col) {
    if (ended || paused) return false;
    final d = at(row, col);
    if (d == null) return false;
    defenders.remove(d);
    effect(row, col + .5, 'place');
    return true;
  }

  bool collect(int id) {
    if (paused || ended) return false;
    final found = pickups.where((p) => p.id == id).firstOrNull;
    if (found == null || (found.tuna && tuna >= 3)) return false;
    if (found.tuna) {
      tuna++;
    } else {
      catnip += 25;
    }
    pickups.remove(found);
    effect(found.row, found.x, 'collect');
    return true;
  }

  bool moveCart(int fromRow, int toRow) {
    if (ended ||
        paused ||
        !carts.contains(fromRow * 9 + 1) ||
        !validCell(toRow, 1) ||
        carts.contains(toRow * 9 + 1) ||
        at(toRow, 1) != null) {
      return false;
    }
    carts.remove(fromRow * 9 + 1);
    carts.add(toRow * 9 + 1);
    at(fromRow, 1)?.row = toRow;
    return true;
  }

  bool feed(int row, int col) {
    if (ended || paused || tuna <= 0) {
      say('Recoge una lata de atún.');
      return false;
    }
    final d = at(row, col);
    if (d == null ||
        d.kind == MzCat.bomb ||
        d.powerUntil > time ||
        d.burstLeft > 0) {
      return false;
    }
    final group = level.world == MzWorld.future && node(row, col) >= 0
        ? defenders
              .where((other) => node(other.row, other.col) == node(row, col))
              .toList()
        : [d];
    if (d.kind == MzCat.mine && !hasCopySpace()) {
      say('Necesitas una casilla libre para las cajas.');
      return false;
    }
    tuna--;
    for (final cat in group) {
      if (cat.kind != MzCat.bomb &&
          cat.powerUntil <= time &&
          cat.burstLeft == 0) {
        _power(cat);
      }
    }
    say('¡Atún premium!');
    return true;
  }

  int node(int row, int col) =>
      level.world == MzWorld.future && [1, 3, 5].contains(col) && row.isEven
      ? (row + col) % 3
      : -1;
  bool hasCopySpace() {
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 9; c++) {
        if (free(r, c)) return true;
      }
    }
    return false;
  }

  double multiplier(MzCat kind) =>
      time < lionUntil && (kind == MzCat.launcher || kind == MzCat.boomerang)
      ? 3
      : 1;
  List<MzInvader> targets(MzDefender d) =>
      invaders
          .where((e) => e.alive && e.row == d.row && e.x >= d.col + .2)
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));

  void _power(MzDefender d) {
    effect(d.row, d.col + .5, 'tuna', 1);
    switch (d.kind) {
      case MzCat.launcher:
        d.burstLeft = 60;
        d.burst = 0;
      case MzCat.sunflower:
        for (var i = 0; i < 15; i++) {
          pickups.add(
            MzPickup(
              nextId++,
              d.row,
              (d.col + .15 + (i % 5) * .18).clamp(.1, 8.9),
            ),
          );
        }
      case MzCat.barrier:
        d.hp = 3000;
        d.armor = 6000;
      case MzCat.ice:
        for (final e in invaders.where((e) => e.row == d.row && e.alive)) {
          hit(e, 200);
          freeze(e, 2);
        }
      case MzCat.mine:
        d.age = 8;
        final cells = <int>[
          for (var r = 0; r < 5; r++)
            for (var c = 0; c < 9; c++)
              if (free(r, c)) r * 9 + c,
        ];
        for (var i = 0; i < 2 && cells.isNotEmpty; i++) {
          final cell = cells.removeAt(random(cells.length));
          defenders.add(
            MzDefender(nextId++, MzCat.mine, cell ~/ 9, cell % 9)..age = 8,
          );
        }
      case MzCat.catapult:
        for (final e in invaders.where((e) => e.alive).take(12)) {
          projectile(d, 150, arc: true, target: e.id, row: e.row);
        }
      case MzCat.boomerang:
        for (var i = 0; i < 3; i++) {
          fish(d, 40 * multiplier(d.kind));
        }
      case MzCat.spring:
        for (final e in targets(d).where((e) => e.x < d.col + 4)) {
          push(e, 3);
        }
      case MzCat.lightning:
        for (final e in invaders.where((e) => e.alive).take(8)) {
          hit(e, 120);
          effect(e.row, e.x, 'electric');
        }
      case MzCat.laser:
        d.powerUntil = time + 3;
      case MzCat.bomb:
        break;
    }
  }

  /// Caller persists the spent balance and resulting snapshot together.
  bool human(MzPower power, int row, double x) {
    if (ended || paused || time < humanUntil || !validCell(row, x.floor())) {
      return false;
    }
    final area = invaders
        .where(
          (e) =>
              e.alive &&
              (power != MzPower.pointer || e.kind != MzEnemy.boss) &&
              (e.row - row).abs() <= 1 &&
              (e.x - x).abs() <= (power == MzPower.pointer ? 2 : 1.5),
        )
        .toList();
    if (area.isEmpty) {
      say('Apunta a un invasor.');
      return false;
    }
    switch (power) {
      case MzPower.pinch:
        area.sort(
          (a, b) => ((a.row - row).abs() + (a.x - x).abs()).compareTo(
            (b.row - row).abs() + (b.x - x).abs(),
          ),
        );
        final e = area.first;
        hit(
          e,
          e.kind == MzEnemy.boss
              ? 250
              : e.kind.elite
              ? 500
              : 10000,
        );
      case MzPower.pointer:
        final chosen = area.take(5).toList();
        for (final e in chosen) {
          if (e.kind == MzEnemy.boss) continue;
          e.lureUntil = time + 2;
          e.lureX = x.clamp(1.5, 8.8);
          effect(e.row, e.x, 'fish');
        }
      case MzPower.spray:
        for (final e in area) {
          hit(e, 150);
          freeze(e, e.kind == MzEnemy.boss ? .5 : 2);
          effect(e.row, e.x, 'electric');
        }
    }
    humanUntil = time + 15;
    _deaths();
    return true;
  }

  bool summonLion() {
    if (ended || paused || lionUsed) return false;
    lionUsed = true;
    lionUntil = time + 15;
    for (final e in invaders) {
      hit(e, 200);
    }
    for (var r = 0; r < 5; r++) {
      effect(r, 4.5, 'lion', 1.5);
    }
    say('¡El Gran León potencia los ovillos y bumeranes!', 5);
    return true;
  }

  bool buyTuna() {
    if (ended || paused || boughtTuna || tuna >= 3) return false;
    boughtTuna = true;
    tuna++;
    return true;
  }

  void freeze(MzInvader e, double seconds) {
    if (e.immuneUntil > time || !e.alive) return;
    e.frozenUntil = time + seconds;
    e.immuneUntil = time + seconds + 3;
  }

  void hit(MzInvader e, double amount, {bool pierce = false}) {
    if (!e.alive) return;
    if (!pierce) {
      final absorbed = math.min(e.armor, amount);
      e.armor -= absorbed;
      amount -= absorbed;
    }
    e.hp -= amount;
  }

  void hurt(MzDefender d, double amount) {
    final absorbed = math.min(d.armor, amount);
    d.armor -= absorbed;
    d.hp -= amount - absorbed;
  }

  void push(MzInvader e, double amount) {
    if (e.kind == MzEnemy.boss) return;
    final old = e.x;
    e.x += amount;
    if (level.world == MzWorld.pirates &&
        water(e.row, 6) &&
        old < 7 &&
        e.x >= 6) {
      e.hp = 0;
    }
    if (e.x > 10) {
      if (e.kind.elite) {
        e.x = 9.7;
      } else {
        e.hp = 0;
      }
    }
  }

  void effect(int row, double x, String type, [double ttl = .5]) {
    if (effects.length < 120) effects.add(MzEffect(row, x, type, ttl: ttl));
  }

  void projectile(
    MzDefender d,
    double damage, {
    bool ice = false,
    bool arc = false,
    int? target,
    int? row,
  }) => projectiles.add(
    MzProjectile(
      nextId++,
      row ?? d.row,
      d.col + .8,
      damage,
      ice: ice,
      arc: arc,
      target: target,
    ),
  );

  void advance(double seconds) {
    if (paused || ended || seconds <= 0) return;
    accumulator += seconds;
    while (accumulator + 1e-10 >= step && !ended) {
      accumulator -= step;
      _tick(step);
    }
  }

  void spawn(MzEnemy kind, int row, {bool shiny = false, double x = 9.6}) {
    final e = MzInvader(nextId++, kind, row, x: x, shiny: shiny);
    invaders.add(e);
    if (kind == MzEnemy.corsair) {
      e.x = 5.8;
      warnings.add(MzWarning(row, 5, 'landing', time + 2));
      e.frozenUntil = time + 2;
    }
    if (kind == MzEnemy.miner) {
      e.x = 3.8;
      warnings.add(MzWarning(row, 3, 'landing', time + 2));
      e.frozenUntil = time + 2;
    }
    if (kind == MzEnemy.flag) say('¡Se acerca una horda de michis!', 4);
    if (kind == MzEnemy.boss) {
      e.x = 8.7;
      e.special = 5;
      say('¡Dr. Cat-trófico ha llegado!', 5);
    }
  }

  void _tick(double dt) {
    time += dt;
    if (level.mode != MzMode.survival) {
      while (spawnIndex < schedule.length &&
          schedule[spawnIndex].time <= time) {
        final s = schedule[spawnIndex++];
        spawn(s.kind, s.row, shiny: s.shiny);
      }
    } else if (time >= survivalAt) {
      wave++;
      survivalAt += 30;
      final choices = level.enemies.where((e) => e != MzEnemy.boss).toList();
      for (var i = 0; i < math.min(15, 3 + wave); i++) {
        spawn(
          choices[random(choices.length)],
          random(5),
          shiny: i == 0,
          x: 9.6 + i * .25,
        );
      }
      say('Supervivencia · oleada $wave', 4);
      if (wave % 3 == 0) {
        catnip += 100;
      }
    }
    sky -= dt;
    if (sky <= 0) {
      sky += 8;
      pickups.add(
        MzPickup(
          nextId++,
          level.rows[random(level.rows.length)],
          .5 + random(8),
        ),
      );
    }
    for (final p in pickups.toList()) {
      p.ttl -= dt;
      if (autoCollect) collect(p.id);
    }
    pickups.removeWhere((p) => p.ttl <= 0);
    for (final f in effects) {
      f.ttl -= dt;
    }
    effects.removeWhere((f) => f.ttl <= 0);
    _world(dt);

    for (final d in defenders.toList()) {
      if (d.hp <= 0) continue;
      d.age += dt;
      d.attack -= dt;
      final spec = mzCats[d.kind]!;
      final enemies = targets(d);
      if (d.burstLeft > 0) {
        d.burst -= dt;
        while (d.burst <= 0 && d.burstLeft > 0) {
          projectile(d, 10 * multiplier(d.kind));
          d.burst += 1 / 60;
          d.burstLeft--;
        }
      }
      if (d.kind == MzCat.sunflower && d.attack <= 0) {
        pickups.add(MzPickup(nextId++, d.row, d.col + .5));
        d.attack += 24;
        effect(d.row, d.col + .5, 'sun');
      }
      if (d.kind == MzCat.bomb && d.age >= .8) {
        blast(d.row, d.col + .5, 1200);
        d.hp = 0;
        continue;
      }
      if (d.kind == MzCat.mine &&
          d.armed &&
          enemies.any((e) => e.kind != MzEnemy.parrot && e.x < d.col + 1.2)) {
        final e = enemies.firstWhere(
          (e) => e.kind != MzEnemy.parrot && e.x < d.col + 1.2,
        );
        hit(e, 1200);
        effect(d.row, d.col + .5, 'boom', .8);
        d.hp = 0;
        continue;
      }
      if (d.kind == MzCat.laser && enemies.isNotEmpty) {
        for (final e in enemies) {
          hit(e, (d.powerUntil > time ? 150 : 30) * dt, pierce: true);
        }
        effect(d.row, d.col + .8, 'laser', .05);
        continue;
      }
      final frontTomb =
          tombs.keys
              .where((key) => key ~/ 9 == d.row && key % 9 > d.col)
              .toList()
            ..sort();
      if (d.attack > 0 || (enemies.isEmpty && frontTomb.isEmpty)) continue;
      switch (d.kind) {
        case MzCat.launcher || MzCat.ice:
          projectile(
            d,
            spec.damage * multiplier(d.kind),
            ice: d.kind == MzCat.ice,
          );
          d.attack = spec.interval;
        case MzCat.catapult:
          if (enemies.isNotEmpty) {
            projectile(d, spec.damage, arc: true, target: enemies.first.id);
            d.attack = spec.interval;
          }
        case MzCat.boomerang:
          fish(d, 20 * multiplier(d.kind));
          d.attack = spec.interval;
        case MzCat.lightning:
          final chain = invaders
              .where(
                (e) =>
                    e.alive &&
                    e.x >= d.col &&
                    (e.row - d.row).abs() <= 1 &&
                    (e.x - (enemies.firstOrNull?.x ?? d.col)).abs() < 2.5,
              )
              .take(3);
          for (final e in chain) {
            hit(e, 15);
            effect(e.row, e.x, 'electric');
          }
          d.attack = spec.interval;
        case MzCat.spring:
          if (enemies.isNotEmpty && enemies.first.x < d.col + 2) {
            push(enemies.first, 1.5);
            effect(d.row, d.col + .5, 'fish');
            d.attack = 5;
          }
        default:
          break;
      }
    }
    _projectiles(dt);
    _deaths();
    for (final e in invaders.toList()) {
      if (!e.alive || e.frozenUntil > time) continue;
      _special(e, dt);
      if (e.kind == MzEnemy.boss) continue;
      if (e.lureUntil > 0) {
        if (time < e.lureUntil) {
          final distance = e.lureX - e.x;
          e.x += distance.sign * math.min(distance.abs(), 1.6 * dt);
          if (water(e.row, e.x.floor())) e.hp = 0;
          continue;
        }
        e.lureUntil = 0;
        for (final other in invaders.where(
          (other) =>
              other.id != e.id &&
              other.alive &&
              other.lureUntil > 0 &&
              other.row == e.row &&
              (other.x - e.x).abs() < .8,
        )) {
          hit(e, 50);
          hit(other, 50);
        }
        push(e, 2);
      }
      final speed = e.slowUntil > time ? .6 : 1.0;
      if (e.captive != null) {
        e.x += .4 * dt;
        if (e.x > 10) {
          captives.removeWhere((d) => d.id == e.captive);
          e.hp = 0;
          losses++;
        }
        continue;
      }
      final blockers = defenders
          .where(
            (d) =>
                d.hp > 0 &&
                d.row == e.row &&
                e.x >= d.col + .25 &&
                e.x <= d.col + 1.15,
          )
          .toList();
      if (blockers.isNotEmpty && e.kind != MzEnemy.parrot) {
        e.attack -= dt * speed;
        if (e.attack <= 0) {
          hurt(blockers.last, 50);
          e.attack += 1;
          effect(e.row, e.x, 'bite', .2);
        }
      } else {
        e.x -= e.kind.speed * dt * speed;
      }
      if (water(e.row, e.x.floor())) e.hp = 0;
    }
    _deaths();
    for (var row = 0; row < 5; row++) {
      if (roombaX[row] >= -.8 && roombaX[row] < 11) {
        roombaX[row] += 8 * dt;
        for (final e in invaders.where(
          (e) => e.alive && e.row == row && e.x <= roombaX[row] + .6,
        )) {
          if (e.kind == MzEnemy.boss) {
            hit(e, 600);
            roombaX[row] = 11;
          } else {
            e.hp = 0;
          }
        }
      }
      final breaches = invaders
          .where((e) => e.alive && e.row == row && e.x < -.15)
          .toList();
      if (breaches.isNotEmpty) {
        if (roombas[row]) {
          roombas[row] = false;
          roombaX[row] = -.8;
          for (final e in breaches) {
            e.hp = 0;
          }
          say('¡Roomba al rescate!');
        } else if (roombaX[row] < -.8 || roombaX[row] >= 11) {
          lost = true;
        }
      }
    }
    _deaths();
    if (!lost &&
        level.mode != MzMode.survival &&
        spawnIndex == schedule.length &&
        invaders.isEmpty &&
        warnings.isEmpty) {
      won = true;
    }
  }

  void _tombHit(int cell, double damage) {
    final hp = (tombs[cell] ?? 0) - damage;
    if (hp <= 0) {
      tombs.remove(cell);
    } else {
      tombs[cell] = hp;
    }
  }

  void blast(int row, double x, double damage) {
    for (final e in invaders.where(
      (e) => e.alive && (e.row - row).abs() <= 1 && (e.x - x).abs() <= 1.5,
    )) {
      hit(e, damage);
    }
    for (final cell in tombs.keys.toList()) {
      if ((cell ~/ 9 - row).abs() <= 1 && (cell % 9 + .5 - x).abs() <= 1.5) {
        _tombHit(cell, damage);
      }
    }
    effect(row, x, 'boom', .8);
  }

  void _projectiles(double dt) {
    final spent = <int>{};
    for (final p in projectiles) {
      if (p.fish) {
        final old = p.x;
        p.x += (p.returning ? -5 : 5) * dt;
        final already = p.returning ? p.inboundHits : p.outboundHits;
        final stones = !p.returning
            ? tombs.keys
                  .where(
                    (cell) =>
                        cell ~/ 9 == p.row &&
                        cell % 9 + .5 >= old - .1 &&
                        cell % 9 + .5 <= p.x + .3,
                  )
                  .toList()
            : <int>[];
        if (stones.isNotEmpty) {
          _tombHit(stones.first, p.damage);
          p.returning = true;
        }
        final targets =
            invaders
                .where(
                  (e) =>
                      e.alive &&
                      e.row == p.row &&
                      !already.contains(e.id) &&
                      e.x >= math.min(old, p.x) - .3 &&
                      e.x <= math.max(old, p.x) + .3,
                )
                .toList()
              ..sort(
                (a, b) => p.returning ? b.x.compareTo(a.x) : a.x.compareTo(b.x),
              );
        if (stones.isEmpty) {
          for (final e in targets) {
            if (already.length >= 3) break;
            hit(e, p.damage);
            already.add(e.id);
            effect(e.row, e.x, 'fish', .2);
          }
        }
        if (!p.returning && (p.x >= 9.8 || p.outboundHits.length >= 3)) {
          p.returning = true;
        }
        if (p.returning && p.x <= p.origin) spent.add(p.id);
        continue;
      }
      final old = p.x;
      p.x += 5 * dt;
      final enemies =
          invaders
              .where(
                (e) =>
                    e.alive &&
                    e.row == p.row &&
                    (p.target == null || p.target == e.id) &&
                    e.x >= old - .35 &&
                    e.x <= p.x + .35,
              )
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));
      final stones = !p.arc
          ? tombs.keys
                .where(
                  (key) =>
                      key ~/ 9 == p.row &&
                      key % 9 + .5 >= old &&
                      key % 9 + .5 <= p.x + .35,
                )
                .toList()
          : <int>[];
      if (stones.isNotEmpty &&
          (enemies.isEmpty || stones.first % 9 + .5 < enemies.first.x)) {
        _tombHit(stones.first, p.damage);
        spent.add(p.id);
      } else if (enemies.isNotEmpty) {
        final e = enemies.first;
        hit(e, p.damage);
        if (p.ice) e.slowUntil = time + 3;
        effect(e.row, e.x, p.ice ? 'ice' : 'hit', .2);
        spent.add(p.id);
      }
      if (p.x > 11 ||
          (p.target != null &&
              !invaders.any((e) => e.id == p.target && e.alive))) {
        spent.add(p.id);
      }
    }
    projectiles.removeWhere((p) => spent.contains(p.id));
  }

  void fish(MzDefender d, double damage) => projectiles.add(
    MzProjectile(nextId++, d.row, d.col + .8, damage)..fish = true,
  );

  void _deaths() {
    for (final e in invaders.where((e) => !e.alive).toList()) {
      kills++;
      effect(e.row, e.x, 'poof');
      if (e.shiny) {
        pickups.add(
          MzPickup(nextId++, e.row, e.x.clamp(.2, 8.8), tuna: true, ttl: 18),
        );
      }
      if (e.captive != null) {
        final d = captives.where((d) => d.id == e.captive).firstOrNull;
        if (d != null) {
          captives.remove(d);
          final cells = [
            d.col,
            for (var c = 0; c < 9; c++)
              if (c != d.col) c,
          ]..sort((a, b) => (a - d.col).abs().compareTo((b - d.col).abs()));
          final cell = cells.where((c) => free(d.row, c)).firstOrNull;
          if (cell != null) {
            d.col = cell;
            defenders.add(d);
          } else {
            losses++;
          }
        }
      }
    }
    invaders.removeWhere((e) => !e.alive);
    for (final d in defenders.where((d) => d.hp <= 0)) {
      if (d.kind != MzCat.bomb && d.kind != MzCat.mine) losses++;
      effect(d.row, d.col + .5, 'poof');
    }
    defenders.removeWhere((d) => d.hp <= 0);
  }

  void _special(MzInvader e, double dt) {
    e.special -= dt;
    if (e.kind == MzEnemy.parrot && e.captive == null) {
      final d = defenders
          .where((d) => d.row == e.row && (d.col + .5 - e.x).abs() < .45)
          .firstOrNull;
      if (d != null) {
        e.captive = d.id;
        defenders.remove(d);
        captives.add(d);
        say('¡El loro se lleva un gato!');
      }
    }
    if (e.special > 0) return;
    e.special = e.kind == MzEnemy.boss ? 8 : 12;
    switch (e.kind) {
      case MzEnemy.thief:
        final p = pickups.where((p) => !p.tuna && p.row == e.row).firstOrNull;
        if (p != null) {
          pickups.remove(p);
          effect(e.row, e.x, 'collect');
        }
      case MzEnemy.pianist:
        final group = invaders
            .where(
              (other) =>
                  other.id != e.id &&
                  other.kind != MzEnemy.boss &&
                  (other.x - e.x).abs() < 2,
            )
            .toList();
        for (final other in group) {
          final dest = (other.row + (random(2) == 0 ? -1 : 1)).clamp(0, 4);
          other.row = dest;
        }
        say('¡El piano hace bailar a la horda!');
      case MzEnemy.cannon:
        final d = defenders.where((d) => d.row == e.row).firstOrNull;
        if (d != null) {
          warnings.add(MzWarning(d.row, d.col, 'bone', time + 2));
        }
      case MzEnemy.shield:
        for (final other in invaders.where(
          (other) =>
              other.kind != MzEnemy.boss &&
              other.row == e.row &&
              (other.x - e.x).abs() < 1.5,
        )) {
          other.armor = math.max(other.armor, 150);
        }
      case MzEnemy.boss:
        final phase = e.hp < 4200
            ? 3
            : e.hp < 8400
            ? 2
            : 1;
        e.row = (e.row + 1) % 5;
        if (bossAdds < 20) {
          for (var i = 0; i < 2; i++) {
            spawn(
              phase == 3 ? MzEnemy.mecha : MzEnemy.common,
              (e.row + i * 2) % 5,
              shiny: bossAdds % 4 == 0,
            );
            bossAdds++;
          }
        }
        if (phase >= 2) {
          for (var i = 0; i < 2; i++) {
            warnings.add(MzWarning(random(5), random(7), 'stomp', time + 2));
          }
        }
        say(
          'Dr. Cat-trófico · fase $phase · apunta al núcleo del carril ${e.row + 1}',
        );
      default:
        break;
    }
  }

  void _world(double dt) {
    for (final warning in warnings.where((w) => w.at <= time).toList()) {
      if (warning.type == 'bridge') {
        bridges.remove(warning.row * 9 + warning.col);
        at(warning.row, warning.col)?.hp = 0;
        for (final e in invaders.where(
          (e) => e.row == warning.row && e.x.floor() == warning.col,
        )) {
          e.hp = 0;
        }
        say('¡Tablón roto! Empuja a los invasores al agua.');
      } else if (warning.type == 'stomp' || warning.type == 'bone') {
        final d = at(warning.row, warning.col);
        if (d != null) hurt(d, warning.type == 'stomp' ? 500 : 120);
        effect(warning.row, warning.col + .5, 'boom');
      }
      warnings.remove(warning);
    }
    worldTimer -= dt;
    if (worldTimer > 0) return;
    worldTimer += 30;
    if (level.world == MzWorld.pirates && level.number >= 4) {
      final cells = bridges.toList();
      if (cells.isNotEmpty) {
        final key = cells[random(cells.length)];
        warnings.add(MzWarning(key ~/ 9, key % 9, 'bridge', time + 2));
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'level': level.id,
    'mode': level.mode.index,
    'seed': level.seed,
    'deck': deck.map((d) => d.index).toList(),
    'time': time,
    'accumulator': accumulator,
    'rng': rng,
    'id': nextId,
    'catnip': catnip,
    'tuna': tuna,
    'spawn': spawnIndex,
    'sky': sky,
    'worldTimer': worldTimer,
    'human': humanUntil,
    'lion': lionUntil,
    'lionUsed': lionUsed,
    'bought': boughtTuna,
    'losses': losses,
    'kills': kills,
    'wave': wave,
    'adds': bossAdds,
    'survivalAt': survivalAt,
    'won': won,
    'lost': lost,
    'roombas': roombas,
    'roombaX': roombaX,
    'auto': autoCollect,
    'defenders': defenders.map((e) => e.toJson()).toList(),
    'captives': captives.map((e) => e.toJson()).toList(),
    'invaders': invaders.map((e) => e.toJson()).toList(),
    'projectiles': projectiles.map((e) => e.toJson()).toList(),
    'pickups': pickups.map((e) => e.toJson()).toList(),
    'warnings': warnings.map((e) => e.toJson()).toList(),
    'tombs': tombs.map((k, v) => MapEntry('$k', v)),
    'bridges': bridges.toList(),
    'carts': carts.toList(),
    'cooldowns': cooldowns.map((k, v) => MapEntry('${k.index}', v)),
  };

  factory MzSimulation.fromJson(Map<String, dynamic> j) {
    if (j['v'] != version) {
      throw const FormatException('Versión de partida incompatible');
    }
    final id = j['level'] as int;
    if (id < 0 || id >= 60) throw const FormatException('Nivel inválido');
    final sim = MzSimulation(
      MzLevel(
        id,
        mode: MzMode.values[j['mode'] as int],
        seed: j['seed'] as int,
      ),
      deck: (j['deck'] as List).map((i) => MzCat.values[i as int]).toList(),
    );
    sim.time = mzNum(j, 'time');
    sim.accumulator = mzNum(j, 'accumulator');
    sim.rng = j['rng'] as int;
    sim.nextId = j['id'] as int;
    sim.catnip = j['catnip'] as int;
    sim.tuna = j['tuna'] as int;
    sim.spawnIndex = j['spawn'] as int;
    sim.sky = mzNum(j, 'sky');
    sim.worldTimer = mzNum(j, 'worldTimer');
    sim.humanUntil = mzNum(j, 'human');
    sim.lionUntil = mzNum(j, 'lion');
    sim.lionUsed = j['lionUsed'] == true;
    sim.boughtTuna = j['bought'] == true;
    sim.won = j['won'] == true;
    sim.lost = j['lost'] == true;
    sim.autoCollect = j['auto'] == true;
    sim.losses = j['losses'] as int;
    sim.kills = j['kills'] as int;
    sim.wave = j['wave'] as int;
    sim.bossAdds = j['adds'] as int;
    sim.survivalAt = mzNum(j, 'survivalAt');
    for (var i = 0; i < 5; i++) {
      sim.roombas[i] = (j['roombas'] as List)[i] as bool;
      sim.roombaX[i] = ((j['roombaX'] as List)[i] as num).toDouble();
    }
    sim.defenders.addAll(
      (j['defenders'] as List).map((v) => MzDefender.fromJson(mzMap(v))),
    );
    sim.captives.addAll(
      (j['captives'] as List).map((v) => MzDefender.fromJson(mzMap(v))),
    );
    sim.invaders.addAll(
      (j['invaders'] as List).map((v) => MzInvader.fromJson(mzMap(v))),
    );
    sim.projectiles.addAll(
      (j['projectiles'] as List).map((v) => MzProjectile.fromJson(mzMap(v))),
    );
    sim.pickups.addAll(
      (j['pickups'] as List).map((v) => MzPickup.fromJson(mzMap(v))),
    );
    sim.warnings.addAll(
      (j['warnings'] as List).map((v) => MzWarning.fromJson(mzMap(v))),
    );
    sim.tombs
      ..clear()
      ..addAll(
        mzMap(
          j['tombs'],
        ).map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())),
      );
    // Old Egyptian saves retain their IDs and entities, but lose obsolete tombs.
    if (sim.level.world == MzWorld.egypt) sim.tombs.clear();
    sim.bridges
      ..clear()
      ..addAll((j['bridges'] as List).cast<int>());
    sim.carts
      ..clear()
      ..addAll((j['carts'] as List).cast<int>());
    sim.cooldowns.addAll(
      mzMap(j['cooldowns']).map(
        (k, v) => MapEntry(MzCat.values[int.parse(k)], (v as num).toDouble()),
      ),
    );
    sim.paused = true;
    return sim;
  }
}
