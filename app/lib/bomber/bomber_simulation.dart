import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bomber_config.dart';

Map<String, dynamic> objectMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
double valueNum(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
String cellKey(int x, int y) => '${x}_$y';
int bomberHash(int seed, int x, int y) =>
    (seed ^ ((x + 17) * 73856093) ^ ((y + 31) * 19349663)) & 0xffffffff;
Map<String, dynamic> kittenStats() => {
  'alive': true,
  'range': 2,
  'maxBombs': 1,
  'speed': 1.0,
  'paw': false,
  'shieldUntil': 0,
  'immuneUntil': 0,
  'boxUntil': 0,
  'stunUntil': 0,
};
Map<String, dynamic> makeBomberBoard(
  int seed, {
  int columns = BomberConfig.columns,
  int rows = BomberConfig.rows,
  int mapId = 0,
}) {
  final walls = <String, dynamic>{}, crates = <String, dynamic>{};
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < columns; x++) {
      final key = cellKey(x, y);
      if (x == 0 ||
          y == 0 ||
          x == columns - 1 ||
          y == rows - 1 ||
          (x.isEven &&
              y.isEven &&
              !(mapId == 1 && (y == 6 || y == rows - 7)) &&
              !(mapId == 3 && (x == 4 || x == columns - 5)))) {
        walls[key] = true;
      } else if (!((x <= 2 && y >= rows - 3) || (x >= columns - 3 && y <= 2)) &&
          bomberHash(
                    seed,
                    math.min(x, columns - 1 - x),
                    math.min(y, rows - 1 - y),
                  ) %
                  100 <
              [62, 48, 72, 57][mapId]) {
        crates[key] = true;
      }
    }
  }
  return {
    'columns': columns,
    'rows': rows,
    'seed': seed,
    'mapId': mapId,
    'walls': walls,
    'crates': crates,
  };
}

/// Logical positions and collisions are independent from the cats' visual poses.
class BomberSimulation extends ChangeNotifier {
  BomberSimulation.training({
    int seed = 42,
    int? now,
    int mapId = 0,
    BomberCat cat = BomberCat.maru,
    Map<String, dynamic> outfit = const {},
  }) : localId = 'maru',
       online = false {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    state = {
      'status': 'playing',
      'createdAt': time,
      'startsAt': time + 3000,
      'board': makeBomberBoard(seed, mapId: mapId),
      'players': {'maru': kittenStats(), 'lady': kittenStats()},
      'bombs': <String, dynamic>{},
      'powers': <String, dynamic>{},
      'events': <String, dynamic>{},
    };
    positions = {
      'maru': Offset(1.5, rows - 1.5),
      'lady': Offset(columns - 1.5, 1.5),
    };
    members = {
      'maru': {'cat': cat.name, 'name': cat.label, 'outfit': outfit},
      'lady': {
        'cat': cat == BomberCat.lady ? 'milo' : 'lady',
        'name': 'Michi IA',
      },
    };
  }
  BomberSimulation.network(this.localId) : online = true;
  final String localId;
  final bool online;
  Map<String, dynamic> state = {}, members = {};
  Map<String, Offset> positions = {}, velocities = {};
  final Map<String, Offset> targets = {};
  final Map<String, int> targetTimes = {};
  final Map<String, String> _exitingCrates = {};
  final Map<String, Set<String>> _walkOffBombs = {};
  Offset input = Offset.zero;
  int clockOffset = 0, now = 0, sequence = 0, _botBombAt = 0;
  Offset? _botGoal;
  String? lastPower;
  int powerAt = 0;
  final Set<String> _heardBombs = {}, _heardExplosions = {};
  final Set<String> collectedCoins = {};
  int coins = 0;

  /// Personal pickups in the open spawn corridors, also for online arenas.
  Set<String> get coinCells {
    final walls = objectMap(board['walls']),
        crates = objectMap(board['crates']);
    return {
      for (var y = 1; y < rows - 1; y++)
        for (var x = 1; x < columns - 1; x++)
          if (((x <= 2 && y >= rows - 3) || (x >= columns - 3 && y <= 2)) &&
              !walls.containsKey(cellKey(x, y)) &&
              !crates.containsKey(cellKey(x, y)) &&
              !collectedCoins.contains(cellKey(x, y)))
            cellKey(x, y),
    };
  }

  void Function(String)? onEffect;
  int get columns =>
      (board['columns'] as num?)?.toInt() ?? BomberConfig.columns;
  int get rows => (board['rows'] as num?)?.toInt() ?? BomberConfig.rows;
  Map<String, dynamic> get board => objectMap(state['board']);
  Map<String, dynamic> get players => objectMap(state['players']);
  Map<String, dynamic> get bombs => objectMap(state['bombs']);
  Map<String, dynamic> get powers => objectMap(state['powers']);
  Map<String, dynamic> get events => objectMap(state['events']);
  String get status => state['status'] as String? ?? 'waiting';
  String? get rival => players.keys.where((u) => u != localId).firstOrNull;
  bool get playing => status == 'playing' && now >= valueNum(state['startsAt']);
  bool get finished => status == 'finished' || status == 'abandoned';
  int get remaining => math.max(
    0,
    math.min(
      BomberConfig.duration ~/ 1000,
      state['startsAt'] == null
          ? BomberConfig.duration ~/ 1000
          : ((BomberConfig.duration - now + valueNum(state['startsAt'])) / 1000)
                .ceil(),
    ),
  );
  int get countdown =>
      math.max(0, ((valueNum(state['startsAt']) - now) / 1000).ceil());
  Map<String, dynamic> stats(String uid) => objectMap(players[uid]);
  bool alive(String uid) => stats(uid)['alive'] != false;
  bool canBomb(String uid) =>
      playing &&
      alive(uid) &&
      valueNum(stats(uid)['stunUntil']) <= now &&
      bombs.values.where((v) => objectMap(v)['owner'] == uid).length <
          valueNum(stats(uid)['maxBombs'], 1);
  Offset get local => positions[localId] ?? Offset(1.5, rows - 1.5);
  void receive(Map<String, dynamic> data, {bool resync = false}) {
    state = objectMap(data['state']);
    members = objectMap(data['members']);
    for (final entry in objectMap(data['motion']).entries) {
      final m = objectMap(entry.value),
          p = Offset(valueNum(m['x'], 1.5), valueNum(m['y'], 1.5));
      targets[entry.key] = p;
      targetTimes[entry.key] = valueNum(m['at']).toInt();
      velocities[entry.key] = Offset(valueNum(m['vx']), valueNum(m['vy']));
      if (!positions.containsKey(entry.key) || resync) {
        positions[entry.key] = p;
      }
    }
    for (final id in bombs.keys) {
      if (_heardBombs.add(id)) {
        final b = objectMap(bombs[id]);
        for (final uid in positions.keys) {
          final p = positions[uid]!;
          if (Rect.fromLTWH(
            valueNum(b['x']),
            valueNum(b['y']),
            1,
            1,
          ).inflate(BomberConfig.radius).contains(p)) {
            (_walkOffBombs[uid] ??= {}).add(id);
          }
        }
        onEffect?.call('place');
      }
    }
    for (final id in events.keys) {
      if (_heardExplosions.add(id)) {
        onEffect?.call('explosion');
      }
    }
    notifyListeners();
  }

  Set<String> blast(int x, int y, int range) {
    final cells = {cellKey(x, y)},
        walls = objectMap(board['walls']),
        crates = objectMap(board['crates']);
    for (final d in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1),
    ]) {
      for (var n = 1; n <= range; n++) {
        final key = cellKey(x + (d.dx * n).toInt(), y + (d.dy * n).toInt());
        if (walls.containsKey(key)) {
          break;
        }
        cells.add(key);
        if (crates.containsKey(key)) {
          break;
        }
      }
    }
    return cells;
  }

  bool passable(Offset point, String uid, {bool ignoreBombs = false}) {
    final walls = objectMap(board['walls']),
        crates = objectMap(board['crates']);
    for (final dx in [-BomberConfig.radius, BomberConfig.radius]) {
      for (final dy in [-BomberConfig.radius, BomberConfig.radius]) {
        final x = (point.dx + dx).floor(),
            y = (point.dy + dy).floor(),
            k = cellKey(x, y);
        if (x < 0 ||
            y < 0 ||
            x >= columns ||
            y >= rows ||
            walls.containsKey(k)) {
          return false;
        }
        if (crates.containsKey(k) &&
            valueNum(stats(uid)['boxUntil']) <= now &&
            _exitingCrates[uid] != k) {
          return false;
        }
        if (!ignoreBombs) {
          for (final entry in bombs.entries) {
            final b = objectMap(entry.value);
            if (cellKey((b['x'] as num).toInt(), (b['y'] as num).toInt()) ==
                k) {
              // Walk off a newly placed bomb, then it becomes a solid obstacle.
              if (_walkOffBombs[uid]?.contains(entry.key) != true) {
                return false;
              }
            }
          }
        }
      }
    }
    return true;
  }

  void move(String uid, Offset direction, double dt) {
    if (!alive(uid) || valueNum(stats(uid)['stunUntil']) > now) {
      return;
    }
    if (direction.distance > 1) {
      direction = direction / direction.distance;
    }
    final speed = BomberConfig.speed * valueNum(stats(uid)['speed'], 1),
        delta = direction * speed * dt;
    var p = positions[uid]!;
    final steps = math.max(1, (delta.distance / .1).ceil());
    for (var i = 0; i < steps; i++) {
      final step = delta / steps.toDouble();
      if (passable(p + step, uid)) {
        p += step;
      } else {
        final horizontal = p + Offset(step.dx, 0),
            vertical = p + Offset(0, step.dy);
        if (step.dx != 0 && passable(horizontal, uid)) {
          p = horizontal;
        }
        if (step.dy != 0 && passable(vertical, uid)) {
          p = vertical;
        }
        // Gently center in a corridor when grazing a corner.
        final center = Offset(p.dx.floor() + .5, p.dy.floor() + .5);
        if (step.dx.abs() > step.dy.abs() && (p.dy - center.dy).abs() < .25) {
          final slide =
              p +
              Offset(
                0,
                (center.dy - p.dy).clamp(
                  -dt * speed / steps,
                  dt * speed / steps,
                ),
              );
          if (passable(slide, uid)) {
            p = slide;
          }
        } else if (step.dy.abs() > 0 && (p.dx - center.dx).abs() < .25) {
          final slide =
              p +
              Offset(
                (center.dx - p.dx).clamp(
                  -dt * speed / steps,
                  dt * speed / steps,
                ),
                0,
              );
          if (passable(slide, uid)) {
            p = slide;
          }
        }
      }
    }
    final before = positions[uid]!;
    positions[uid] = p;
    _walkOffBombs[uid]?.removeWhere((id) {
      final b = objectMap(bombs[id]);
      return b.isEmpty ||
          !Rect.fromLTWH(
            valueNum(b['x']),
            valueNum(b['y']),
            1,
            1,
          ).inflate(BomberConfig.radius).contains(p);
    });
    velocities[uid] = dt > 0 ? (p - before) / dt : Offset.zero;
  }

  void tick(double dt, int time) {
    now = time;
    dt = dt.clamp(0, .05);
    if (playing) {
      for (final uid in positions.keys) {
        final p = positions[uid]!, k = cellKey(p.dx.floor(), p.dy.floor());
        if (valueNum(stats(uid)['boxUntil']) <= now &&
            objectMap(board['crates']).containsKey(k)) {
          _exitingCrates.putIfAbsent(uid, () => k);
        }
        final exiting = _exitingCrates[uid];
        if (exiting != null) {
          final parts = exiting.split('_').map(int.parse).toList();
          if (!Rect.fromLTWH(
            parts[0].toDouble(),
            parts[1].toDouble(),
            1,
            1,
          ).inflate(BomberConfig.radius).contains(p)) {
            _exitingCrates.remove(uid);
          }
        }
      }
      move(localId, input, dt);
      if (alive(localId)) {
        final key = cellKey(local.dx.floor(), local.dy.floor());
        if (coinCells.contains(key) && collectedCoins.add(key)) {
          coins += 5;
          onEffect?.call('power');
        }
      }
      if (!online) {
        _bot(dt);
        resolve(time);
        for (final uid in players.keys) {
          pickup(uid, time);
        }
      } else if (rival != null && targets[rival] != null) {
        final uid = rival!,
            target = targets[uid]!,
            age = ((time - (targetTimes[uid] ?? time)) / 1000).clamp(0.0, .15);
        final predicted = target + (velocities[uid] ?? Offset.zero) * age;
        final p = positions[uid] ?? target;
        positions[uid] = (predicted - p).distance > 2
            ? target
            : Offset.lerp(p, predicted, 1 - math.exp(-dt * 16))!;
      }
    }
    notifyListeners();
  }

  bool place(String uid, {String? id}) {
    if (!canBomb(uid)) {
      return false;
    }
    final p = positions[uid]!, k = cellKey(p.dx.floor(), p.dy.floor());
    if (objectMap(board['walls']).containsKey(k) ||
        objectMap(board['crates']).containsKey(k) ||
        bombs.values.any((v) {
          final b = objectMap(v);
          return cellKey((b['x'] as num).toInt(), (b['y'] as num).toInt()) == k;
        })) {
      return false;
    }
    final bombId = id ?? '${uid}_${sequence++}';
    (_walkOffBombs[uid] ??= {}).add(bombId);
    state['bombs'] = bombs
      ..[bombId] = {
        'owner': uid,
        'x': p.dx.floor(),
        'y': p.dy.floor(),
        'range': valueNum(stats(uid)['range'], 2).toInt(),
        'createdAt': now,
        'explodeAt': now + BomberConfig.fuse,
      };
    onEffect?.call('place');
    notifyListeners();
    return true;
  }

  void resolve(int time) {
    final pending = bombs,
        explosions = events,
        crates = objectMap(board['crates']),
        items = powers;
    final queue = pending.keys
        .where((id) => valueNum(objectMap(pending[id])['explodeAt']) <= time)
        .toList();
    final processed = <String>{};
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!processed.add(id) || !pending.containsKey(id)) {
        continue;
      }
      final b = objectMap(pending[id]),
          cells = blast(
            (b['x'] as num).toInt(),
            (b['y'] as num).toInt(),
            (b['range'] as num).toInt(),
          );
      for (final k in cells) {
        if (crates.remove(k) != null) {
          final xy = k.split('_').map(int.parse).toList(),
              roll = bomberHash((board['seed'] as num).toInt(), xy[0], xy[1]);
          if (roll % 100 < 30) {
            final r = (roll >> 8) % 100,
                type = r < 34
                    ? 'yarn'
                    : r < 59
                    ? 'tuna'
                    : r < 84
                    ? 'fish'
                    : r < 92
                    ? 'box'
                    : r < 98
                    ? 'paw'
                    : 'cake';
            items[k] = {
              'type': type,
              'x': xy[0],
              'y': xy[1],
              'availableAt': time + 200,
            };
          }
        } else if (items[k] != null &&
            valueNum(objectMap(items[k])['availableAt']) <= time) {
          items.remove(k);
        }
        for (final other in pending.entries) {
          final v = objectMap(other.value);
          if (other.key != id &&
              cellKey((v['x'] as num).toInt(), (v['y'] as num).toInt()) == k) {
            queue.add(other.key);
          }
        }
      }
      explosions[id] = {
        'cells': cells.toList(),
        'at': time,
        'until': time + BomberConfig.fire,
        'owner': b['owner'],
      };
      pending.remove(id);
      onEffect?.call('explosion');
      state['board'] = board..['crates'] = crates;
    }
    state['bombs'] = pending;
    state['events'] = explosions;
    state['powers'] = items;
    final flameCells = explosions.values
        .where((v) => valueNum(objectMap(v)['until']) > time)
        .expand((v) => (objectMap(v)['cells'] as List).cast<String>())
        .toSet();
    final updated = players;
    for (final uid in updated.keys) {
      final p = stats(uid), at = positions[uid]!;
      if (!alive(uid) ||
          !flameCells.contains(cellKey(at.dx.floor(), at.dy.floor())) ||
          valueNum(p['immuneUntil']) > time) {
        continue;
      }
      if (p['paw'] == true || valueNum(p['shieldUntil']) > time) {
        if (valueNum(p['shieldUntil']) > time) {
          p['boxUntil'] = time + 2000;
        }
        p['paw'] = false;
        p['shieldUntil'] = 0;
        p['immuneUntil'] = time + 800;
        p['stunUntil'] = time + 300;
      } else {
        p['alive'] = false;
        onEffect?.call('hit');
      }
      updated[uid] = p;
    }
    state['players'] = updated;
    final aliveIds = updated.keys.where(alive).toList();
    if (aliveIds.length < 2 ||
        time - valueNum(state['startsAt']) >= BomberConfig.duration) {
      state['status'] = 'finished';
      state['result'] = {
        'winner': aliveIds.length == 1 ? aliveIds.single : 'draw',
        'at': time,
      };
      input = Offset.zero;
    }
    explosions.removeWhere(
      (_, v) => valueNum(objectMap(v)['until']) < time - 3000,
    );
  }

  bool pickup(String uid, int time) {
    final pos = positions[uid]!,
        k = cellKey(pos.dx.floor(), pos.dy.floor()),
        items = powers;
    final item = objectMap(items[k]);
    if (item.isEmpty ||
        !alive(uid) ||
        valueNum(item['availableAt']) > time ||
        (pos - Offset(valueNum(item['x']) + .5, valueNum(item['y']) + .5))
                .distance >
            .6) {
      return false;
    }
    final p = stats(uid), type = item['type'];
    switch (type) {
      case 'yarn':
        p['range'] = math
            .min(BomberConfig.maxRange, valueNum(p['range']) + 1)
            .toInt();
      case 'tuna':
        p['maxBombs'] = math
            .min(BomberConfig.maxBombs, valueNum(p['maxBombs']) + 1)
            .toInt();
      case 'fish':
        p['speed'] = math.min(
          BomberConfig.maxSpeed,
          valueNum(p['speed'], 1) * 1.15,
        );
      case 'box':
        p['boxUntil'] = time + 4000;
      case 'paw':
        p['paw'] = true;
      case 'cake':
        p['shieldUntil'] = time + 5000;
    }
    state['players'] = players..[uid] = p;
    items.remove(k);
    state['powers'] = items;
    if (uid == localId) {
      lastPower = type as String;
      powerAt = time;
      onEffect?.call('power');
    }
    return true;
  }

  List<Offset> _path(
    String uid,
    bool Function(Offset) goal, {
    bool allowCrates = false,
    Set<String> avoid = const {},
  }) {
    final at = positions[uid]!,
        start = Offset(at.dx.floor() + .5, at.dy.floor() + .5);
    final paths = Queue<List<Offset>>()..add([start]),
        seen = {cellKey(start.dx.floor(), start.dy.floor())};
    while (paths.isNotEmpty) {
      final path = paths.removeFirst(), p = path.last;
      if (path.length > 1 && goal(p)) {
        return path;
      }
      for (final d in [
        const Offset(1, 0),
        const Offset(0, 1),
        const Offset(-1, 0),
        const Offset(0, -1),
      ]) {
        final q = p + d, k = cellKey(q.dx.floor(), q.dy.floor());
        if (q.dx < 1 ||
            q.dy < 1 ||
            q.dx >= columns - 1 ||
            q.dy >= rows - 1 ||
            !seen.add(k) ||
            avoid.contains(k) ||
            objectMap(board['walls']).containsKey(k)) {
          continue;
        }
        if (!allowCrates && !passable(q, uid)) {
          continue;
        }
        paths.add([...path, q]);
      }
    }
    return [];
  }

  void _bot(double dt) {
    final uid = rival;
    if (uid == null || !alive(uid)) {
      return;
    }
    final p = positions[uid]!, k = cellKey(p.dx.floor(), p.dy.floor());
    final danger =
        bombs.values.expand((v) {
          final b = objectMap(v);
          return blast(
            (b['x'] as num).toInt(),
            (b['y'] as num).toInt(),
            (b['range'] as num).toInt(),
          );
        }).toSet()..addAll(
          events.values
              .where((v) => valueNum(objectMap(v)['until']) > now)
              .expand((v) => (objectMap(v)['cells'] as List).cast<String>()),
        );
    if (_botGoal == null ||
        (p - _botGoal!).distance < .09 ||
        !passable(_botGoal!, uid) ||
        (danger.contains(k) && _botGoal == null)) {
      List<Offset> path;
      if (danger.contains(k)) {
        path = _path(
          uid,
          (q) => !danger.contains(cellKey(q.dx.floor(), q.dy.floor())),
          avoid: events.values
              .where((v) => valueNum(objectMap(v)['until']) > now)
              .expand((v) => (objectMap(v)['cells'] as List).cast<String>())
              .toSet(),
        );
      } else {
        path = _path(
          uid,
          (q) =>
              (q - local).distance < 2 ||
              [
                const Offset(1, 0),
                const Offset(-1, 0),
                const Offset(0, 1),
                const Offset(0, -1),
              ].any(
                (d) => objectMap(board['crates']).containsKey(
                  cellKey((q.dx + d.dx).floor(), (q.dy + d.dy).floor()),
                ),
              ),
          avoid: danger,
        );
      }
      final center = Offset(p.dx.floor() + .5, p.dy.floor() + .5);
      _botGoal = (p - center).distance > .1
          ? center
          : (path.length > 1 ? path[1] : null);
      if (!danger.contains(k) &&
          now - _botBombAt > 3000 &&
          canBomb(uid) &&
          ((p - local).distance < 3 ||
              path.length <= 1 ||
              [
                const Offset(1, 0),
                const Offset(-1, 0),
                const Offset(0, 1),
                const Offset(0, -1),
              ].any(
                (d) => objectMap(board['crates']).containsKey(
                  cellKey((p.dx + d.dx).floor(), (p.dy + d.dy).floor()),
                ),
              ))) {
        if (place(uid)) {
          _botBombAt = now;
          _botGoal = null;
        }
      }
    }
    if (_botGoal != null) {
      final d = _botGoal! - p;
      move(
        uid,
        d.distance == 0
            ? Offset.zero
            : d /
                  math.max(
                    d.distance,
                    BomberConfig.speed * valueNum(stats(uid)['speed'], 1) * dt,
                  ),
        dt,
      );
    }
  }
}
