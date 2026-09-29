import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/game.dart';

void main() {
  test('Crossed row and column clear simultaneously and reward two lines', () {
    final g = BlockGame(random: Random(1));
    for (var x = 1; x < 8; x++) {
      g.board[x] = 1;
      g.board[x * 8] = 1;
    }
    g.tray = [0, 1, 2];
    g.selected = 0;
    expect(g.place(0, 0), 11);
    expect(g.board.every((v) => v == 0), isTrue);
    expect(g.lastClearedRows, [0]);
    expect(g.lastClearedColumns, [0]);
    expect(g.lastClearedTiles.length, 15);
    expect(g.lastClearedTiles[0], 1);
    expect(g.score, 210);
    expect(g.tray[0], isNull);
  });
  test('Invalid placement does not mutate board, tray or score', () {
    final g = BlockGame();
    g.tray = [2, 1, 0];
    g.selected = 0;
    final before = g.toJson().toString();
    expect(g.place(7, 0), isNull);
    expect(g.toJson().toString(), before);
  });
  test('Detects no legal moves and restores a saved board', () {
    final g = BlockGame();
    g.board = List.filled(64, 1);
    g.tray = [0, null, null];
    expect(g.over, isTrue);
    final restored = BlockGame()..restore(g.toJson());
    expect(restored.over, isTrue);
    expect(restored.board, g.board);
  });
}
