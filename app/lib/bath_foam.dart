import 'package:flutter/material.dart';

class FoamPatch {
  final Offset position;
  final double strength;
  const FoamPatch(this.position, this.strength);
}

/// Normalized soap marks; only water below the nozzle can dissolve them.
class BathFoam {
  final List<FoamPatch> _patches = [];
  double deposited = 0, removed = 0;
  List<FoamPatch> get patches => List.unmodifiable(_patches);
  double get progress => deposited == 0 ? 0 : (removed / deposited).clamp(0, 1);
  bool get finished => deposited > 0 && _patches.isEmpty;
  void clear() {
    _patches.clear();
    deposited = removed = 0;
  }

  void soap(Offset point, double amount) {
    if (amount <= 0) return;
    final p = Offset(point.dx.clamp(.05, .95), point.dy.clamp(.05, .95));
    final near = _patches.indexWhere((e) => (e.position - p).distance < .045);
    if (near >= 0) {
      final old = _patches[near];
      _patches[near] = FoamPatch(old.position, old.strength + amount);
    } else {
      _patches.add(FoamPatch(p, amount));
    }
    deposited += amount;
  }

  void water(Offset nozzle, double amount) {
    for (var i = _patches.length - 1; i >= 0; i--) {
      final patch = _patches[i];
      if ((patch.position.dx - nozzle.dx).abs() > .12 ||
          patch.position.dy < nozzle.dy) {
        continue;
      }
      final lost = amount.clamp(0.0, patch.strength);
      removed += lost;
      final remaining = patch.strength - lost;
      if (remaining < .0001) {
        _patches.removeAt(i);
      } else {
        _patches[i] = FoamPatch(patch.position, remaining);
      }
    }
  }
}
