import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/match3.dart';

SweetGame board() {
  final g = SweetGame(seed: 12345);
  g.cells = List.generate(
    81,
    (i) => SweetCell(color: (i % 9 + 2 * (i ~/ 9)) % 6, jelly: 2),
  );
  return g;
}

void main() {
  test('Initial levels have no matches and at least one legal move', () {
    for (var level = 1; level <= 6; level++) {
      for (var seed = 1; seed <= 12; seed++) {
        final g = SweetGame(level: level, seed: seed);
        expect(g.detect(), isEmpty);
        expect(g.possibleMove, isNotNull);
        expect(g.jellyLeft, greaterThan(0));
      }
    }
  });
  test('Rejects diagonal and unproductive swaps without spending moves', () {
    final g = board();
    final original = g.cells.map((c) => c.color).toList();
    expect(g.move(0, 10), isFalse);
    expect(g.move(0, 1), isFalse);
    expect(g.moves, 26);
    expect(g.cells.map((c) => c.color).toList(), original);
  });
  test('Detects 3, 4, 5 and L/T with exact special priority', () {
    for (final length in [3, 4, 5]) {
      final g = board();
      for (var x = 0; x < length; x++) {
        g.cells[36 + x].color = 0;
      }
      g.cells[36 + length].color = 1;
      final match = g
          .detect(pivot: 38, verticalSwipe: true)
          .firstWhere((m) => m.cells.contains(36));
      expect(
        match.special,
        length == 5
            ? SweetSpecial.bomb
            : length == 4
            ? SweetSpecial.row
            : SweetSpecial.none,
      );
      expect(match.pivot, 38);
    }
    for (final shape in [
      [20, 29, 38, 39, 40],
      [29, 38, 39, 40, 47],
    ]) {
      final g = board();
      for (final i in shape) {
        g.cells[i].color = 5;
      }
      expect(
        g.detect().firstWhere((m) => m.cells.contains(38)).special,
        SweetSpecial.wrapped,
      );
    }
  });
  test('All six special pair fusions work without a match', () {
    for (final pair in [
      [SweetSpecial.row, SweetSpecial.column],
      [SweetSpecial.row, SweetSpecial.wrapped],
      [SweetSpecial.wrapped, SweetSpecial.wrapped],
      [SweetSpecial.bomb, SweetSpecial.row],
      [SweetSpecial.bomb, SweetSpecial.wrapped],
      [SweetSpecial.bomb, SweetSpecial.bomb],
    ]) {
      final g = board();
      g.cells[39].special = pair[0];
      g.cells[40].special = pair[1];
      expect(g.move(39, 40), isTrue);
      expect(g.moves, 25);
      final explosions = g.frames
          .where((f) => f.phase == SweetPhase.clear)
          .toList();
      expect(explosions, isNotEmpty);
      expect(g.score, greaterThan(0));
      expect(g.cells.where((c) => c.playable && c.color < 0), isEmpty);
      expect(g.detect(), isEmpty);
      if (pair.every((s) => s == SweetSpecial.bomb)) {
        expect(explosions.first.affected.length, 81);
      }
      if (pair.every((s) => s == SweetSpecial.wrapped)) {
        expect(explosions[1].affected.length, 25);
      }
    }
  });
  test('Hammer damages one jelly layer and adjacent frosting, keeps moves', () {
    final g = board();
    g.cells[41].frosting = 2;
    g.cells[41].color = -1;
    expect(g.hammer(40), isTrue);
    expect(g.cells[40].jelly, 1);
    expect(g.cells[41].frosting, 1);
    expect(g.moves, 26);
    expect(g.hammers, 2);
  });
  test('Free switch and extra moves are finite; locked cells cannot move', () {
    final g = board();
    expect(g.move(0, 1, free: true), isTrue);
    expect(g.moves, 26);
    expect(g.switches, 1);
    g.cells[0].locked = true;
    expect(g.move(0, 1, free: true), isFalse);
    expect(g.addMoves(), isTrue);
    expect(g.moves, 31);
    expect(g.addMoves(), isFalse);
  });
  test('Saving roundtrips board, blockers, boosters and random state', () {
    final g = SweetGame(level: 4, seed: 849);
    final restored = SweetGame.fromJson(g.toJson());
    expect(restored.toJson(), g.toJson());
    expect(restored.nextInt(6), g.nextInt(6));
  });
  test(
    'Victory turns spare moves into specials and finishes the celebration',
    () {
      final g = board();
      for (final c in g.cells) {
        c.jelly = 0;
      }
      g.cells[40].jelly = 1;
      expect(g.hammer(40), isTrue);
      expect(g.won, isTrue);
      expect(g.moves, 0);
      expect(g.frames.last.phase, SweetPhase.victory);
      expect(g.cells.where((c) => c.special != SweetSpecial.none), isEmpty);
    },
  );
  test('Running out of moves loses only when targets remain', () {
    final g = board()..moves = 1;
    g.cells[39].special = SweetSpecial.row;
    g.cells[40].special = SweetSpecial.column;
    expect(g.move(39, 40), isTrue);
    expect(g.lost, isTrue);
    expect(g.addMoves(), isTrue);
    expect(g.lost, isFalse);
  });
  test('Deadlock shuffle keeps objectives and turns', () {
    final g = board();
    expect(g.possibleMove, isNull);
    final targets = g.jellyLeft;
    g.ensureMoves();
    expect(g.possibleMove, isNotNull);
    expect(g.detect(), isEmpty);
    expect(g.jellyLeft, targets);
    expect(g.moves, 26);
  });
  test('Four and five matches show their special creation before gravity', () {
    for (final length in [4, 5]) {
      final g = board();
      for (var x = 0; x < length; x++) {
        g.cells[36 + x].color = 0;
      }
      g.cells[36 + length].color = 2;
      g.cells[38].color = 1;
      g.cells[47].color = 0;
      expect(g.move(47, 38), isTrue);
      final formation = g.frames.firstWhere(
        (f) => f.phase == SweetPhase.enchant,
      );
      expect(formation.affected, contains(38));
      expect(
        formation.cells[38].special,
        length == 4 ? SweetSpecial.row : SweetSpecial.bomb,
      );
      expect(
        formation.effect,
        length == 4 ? SweetEffect.striped : SweetEffect.bomb,
      );
      final index = g.frames.indexOf(formation);
      expect(g.frames[index + 1].phase, SweetPhase.gravity);
    }
  });
}
