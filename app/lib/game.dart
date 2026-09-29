import 'dart:math';

typedef Cell = ({int x, int y});

class BlockGame {
  static const size = 8;
  static const shapes = <List<Cell>>[
    [(x: 0, y: 0)],
    [(x: 0, y: 0), (x: 1, y: 0)],
    [(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0)],
    [(x: 0, y: 0), (x: 0, y: 1), (x: 0, y: 2)],
    [(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1), (x: 1, y: 1)],
    [(x: 0, y: 0), (x: 0, y: 1), (x: 1, y: 1)],
    [(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 1, y: 1)],
  ];
  final Random random;
  List<int> board = List.filled(size * size, 0);
  List<int?> tray = [];
  int score = 0;
  int combo = 0;
  int lastClearedCount = 0;
  List<int> lastClearedRows = [];
  List<int> lastClearedColumns = [];
  Map<int, int> lastClearedTiles = {};
  int? selected;
  BlockGame({Random? random}) : random = random ?? Random() {
    refill();
  }

  void refill() {
    tray = List.generate(3, (_) => random.nextInt(shapes.length));
    selected = null;
  }

  bool fits(int shape, int x, int y) => shapes[shape].every(
    (c) =>
        x + c.x >= 0 &&
        x + c.x < size &&
        y + c.y >= 0 &&
        y + c.y < size &&
        board[(y + c.y) * size + x + c.x] == 0,
  );
  bool get over => !tray.whereType<int>().any(
    (s) => List.generate(
      size * size,
      (i) => i,
    ).any((i) => fits(s, i % size, i ~/ size)),
  );

  /// Returns earned coins, or null for an invalid placement. Clear lines simultaneously.
  int? place(int x, int y) {
    if (selected == null || tray[selected!] == null) return null;
    final shape = tray[selected!]!;
    if (!fits(shape, x, y)) return null;
    for (final c in shapes[shape]) {
      board[(y + c.y) * size + x + c.x] = shape + 1;
    }
    final rows = [
      for (var y = 0; y < size; y++)
        if (List.generate(size, (x) => board[y * size + x]).every((v) => v > 0))
          y,
    ];
    final cols = [
      for (var x = 0; x < size; x++)
        if (List.generate(size, (y) => board[y * size + x]).every((v) => v > 0))
          x,
    ];
    lastClearedRows = rows;
    lastClearedColumns = cols;
    lastClearedTiles = {
      for (var i = 0; i < board.length; i++)
        if (rows.contains(i ~/ size) || cols.contains(i % size)) i: board[i],
    };
    for (var i = 0; i < board.length; i++) {
      if (rows.contains(i ~/ size) || cols.contains(i % size)) board[i] = 0;
    }
    final lines = rows.length + cols.length;
    lastClearedCount = lines;
    combo = lines > 0 ? combo + 1 : 0;
    score +=
        shapes[shape].length * 10 + lines * 100 + (combo > 1 ? combo * 75 : 0);
    tray[selected!] = null;
    selected = null;
    if (tray.every((s) => s == null)) refill();
    return 1 + lines * 5;
  }

  Map<String, dynamic> toJson() => {
    'board': board,
    'tray': tray,
    'score': score,
    'combo': combo,
  };
  void restore(Map<String, dynamic> json) {
    final b = List<int>.from(json['board'] as List);
    final t = List<int?>.from(json['tray'] as List);
    if (b.length != 64 ||
        b.any((v) => v < 0 || v > shapes.length) ||
        t.length != 3 ||
        t.any((v) => v != null && (v < 0 || v >= shapes.length))) {
      throw const FormatException('Invalid game');
    }
    board = b;
    tray = t;
    score = json['score'] as int;
    combo = json['combo'] as int? ?? 0;
  }
}
