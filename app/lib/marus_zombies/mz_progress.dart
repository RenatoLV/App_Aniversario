import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'mz_catalog.dart';
import 'mz_models.dart';
import 'mz_simulation.dart';
import 'mz_levels.dart';

/// Inventory and suspended combat share one durable value. A paid action can
/// therefore never be restored without its corresponding debit.
class MzProgress {
  MzProgress(this.prefs) {
    reload();
  }
  static const key = 'marusZombies.v1';
  final SharedPreferences prefs;
  Map<String, dynamic> _data = {};
  Future<void> _pending = Future.value();
  String? recovery;
  int get cookies => (_data['cookies'] as int?) ?? 0;
  int get mints => (_data['mints'] as int?) ?? 0;
  bool get lion => _data['lion'] == true;
  bool get autoCollect => _data['auto'] == true;
  bool get reducedMotion => _data['reduced'] == true;
  int get survivalBest => (_data['survivalBest'] as int?) ?? 0;
  Map<String, dynamic> get stars => mzMap(_data['stars'] ?? {});
  int get highest {
    var id = 0;
    while (id < 50 && (stars['$id'] as int? ?? 0) > 0) {
      id++;
    }
    return id;
  }

  // Keep the original milestone counter for existing cards and ancestral unlocks.
  int get cemeteryHighest {
    var n = 0;
    while (n < 10 && (stars['${50 + n}'] as int? ?? 0) > 0) {
      n++;
    }
    return n;
  }

  int get campaignCompleted =>
      mzCampaign.where((l) => (stars['${l.id}'] as int? ?? 0) > 0).length;
  bool levelUnlocked(MzLevel level) {
    if ((stars['${level.id}'] as int? ?? 0) > 0) return true;
    if (level.world == MzWorld.cemetery) {
      return highest >= 10 && level.number <= cemeteryHighest + 1;
    }
    if (level.id >= 10 && highest == 10 && cemeteryHighest < 10) return false;
    return level.id <= highest;
  }

  bool worldUnlocked(MzWorld world) =>
      mzLevelsForWorld(world).any(levelUnlocked);
  int completedToward(int lastId) => mzCampaign
      .take(mzCampaignNumber(lastId))
      .where((l) => (stars['${l.id}'] as int? ?? 0) > 0)
      .length;

  List<MzCat> get deck => ((_data['deck'] as List?) ?? [0, 1, 2])
      .whereType<int>()
      .where((i) => i >= 0 && i < MzCat.values.length)
      .map((i) => MzCat.values[i])
      .toList();
  Map<String, dynamic>? get run =>
      _data['run'] == null ? null : mzMap(_data['run']);
  List<int> get pendingWorlds =>
      ((_data['pendingWorlds'] as List?) ?? []).cast<int>();
  void reload() {
    try {
      _data = mzMap(jsonDecode(prefs.getString(key) ?? '{}'));
    } catch (_) {
      _data = {};
      recovery = 'El guardado no se pudo leer. Se inicia una campaña nueva.';
    }
  }

  Future<void> _write(Map<String, dynamic> Function() update) {
    final task = _pending.then((_) async {
      final next = update();
      if (!await prefs.setString(key, jsonEncode(next))) {
        throw StateError('No se pudo guardar la partida.');
      }
      _data = next;
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> configure({List<MzCat>? deck, bool? auto, bool? reduced}) =>
      _write(
        () => {
          ..._data,
          if (deck != null) 'deck': deck.map((d) => d.index).toList(),
          'auto': ?auto,
          'reduced': ?reduced,
        },
      );
  Future<void> checkpoint(MzSimulation sim, {int spent = 0}) {
    if (spent < 0 || spent > cookies) {
      throw StateError('Galletitas insuficientes.');
    }
    final snapshot = sim.toJson();
    return _write(() {
      if (spent > cookies) throw StateError('Galletitas insuficientes.');
      return {
        ..._data,
        'cookies': cookies - spent,
        'run': snapshot,
        'expenses': (_data['expenses'] as int? ?? 0) + spent,
      };
    });
  }

  Future<void> abandon() =>
      _write(() => {..._data, 'run': null, 'expenses': 0});
  Future<void> unlockLion() async {
    if (lion || mints < 100 || highest < 30) return;
    await _write(
      () => lion ? {..._data} : {..._data, 'lion': true, 'mints': mints - 100},
    );
  }

  MzSimulation? resume() {
    if (run == null) return null;
    try {
      return MzSimulation.fromJson(run!);
    } catch (_) {
      recovery =
          'La partida suspendida necesita reiniciarse. Sus galletitas se devolverán.';
      return null;
    }
  }

  Future<void> recoverIncompatible() async {
    if (run != null && resume() == null) {
      await _write(
        () => {
          ..._data,
          'run': null,
          'cookies': cookies + (_data['expenses'] as int? ?? 0),
          'expenses': 0,
        },
      );
    }
  }

  Future<void> complete(MzSimulation sim) =>
      !sim.ended ? Future.value() : _write(() => _completion(sim));
  Map<String, dynamic> _completion(MzSimulation sim) {
    final nextStars = {...stars}, claims = mzMap(_data['claims'] ?? {});
    var gain = 0, mintGain = 0;
    final pending = [...pendingWorlds];
    var best = survivalBest;
    if (sim.won && sim.level.mode == MzMode.campaign) {
      final id = '${sim.level.id}';
      final int old = nextStars[id] as int? ?? 0;
      final improved = math.max(old, sim.stars);
      nextStars[id] = improved;
      if (old == 0) {
        gain += 100;
        if (sim.level.finale) {
          mintGain += 10;
          pending.add(sim.level.world.index);
        }
      }
      gain += (math.max(0, improved - math.max(1, old)) * 25).toInt();
    } else if (sim.won && sim.level.mode == MzMode.challenge) {
      final id = 'challenge:${sim.level.seed}';
      if (claims[id] != true) {
        claims[id] = true;
        gain += 100;
        mintGain += 5;
      }
    } else if (sim.level.mode == MzMode.survival) {
      best = math.max(best, sim.wave);
      for (var w = 5; w <= sim.wave; w += 5) {
        final id = 'survival:$w';
        if (claims[id] != true) {
          claims[id] = true;
          gain += 100;
          mintGain += 5;
        }
      }
    }
    return {
      ..._data,
      'stars': nextStars,
      'claims': claims,
      'cookies': cookies + gain,
      'mints': mints + mintGain,
      'run': null,
      'expenses': 0,
      'survivalBest': best,
      'pendingWorlds': pending.toSet().toList(),
    };
  }

  Future<void> acknowledgeWorld(int world) => _write(
    () => {
      ..._data,
      'pendingWorlds': pendingWorlds.where((w) => w != world).toList(),
    },
  );
}
