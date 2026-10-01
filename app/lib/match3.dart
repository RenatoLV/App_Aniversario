import 'dart:math' as math;

enum SweetSpecial { none, row, column, wrapped, bomb }

enum SweetEffect { match, striped, wrapped, bomb, fusion }

enum SweetPhase {
  input,
  swap,
  evaluate,
  clear,
  gravity,
  spawn,
  cascade,
  shuffle,
  victory,
  defeat,
  enchant,
}

class SweetCell {
  int color, jelly, frosting;
  SweetSpecial special;
  bool hole, chocolate, locked;
  SweetCell({
    this.color = -1,
    this.jelly = 0,
    this.frosting = 0,
    this.special = SweetSpecial.none,
    this.hole = false,
    this.chocolate = false,
    this.locked = false,
  });
  bool get playable => !hole && frosting == 0 && !chocolate;
  bool get movable => playable && !locked && color >= 0;
  SweetCell copy() => SweetCell(
    color: color,
    jelly: jelly,
    frosting: frosting,
    special: special,
    hole: hole,
    chocolate: chocolate,
    locked: locked,
  );
  Map<String, dynamic> toJson() => {
    'c': color,
    'j': jelly,
    'f': frosting,
    's': special.index,
    'h': hole,
    'ch': chocolate,
    'l': locked,
  };
  factory SweetCell.fromJson(Map<String, dynamic> j) => SweetCell(
    color: j['c'] as int,
    jelly: j['j'] as int,
    frosting: j['f'] as int,
    special: SweetSpecial.values[j['s'] as int],
    hole: j['h'] as bool,
    chocolate: j['ch'] as bool,
    locked: j['l'] as bool,
  );
}

class SweetMatch {
  final Set<int> cells;
  final int pivot;
  final SweetSpecial special;
  SweetMatch(this.cells, this.pivot, this.special);
}

class SweetFrame {
  final List<SweetCell> cells;
  final SweetPhase phase;
  final Set<int> affected;
  final List<int> celebrations;
  final int chain, score, moves;
  final String caption;
  final SweetEffect effect;
  SweetFrame(
    SweetGame game,
    this.phase,
    this.caption, {
    Set<int>? affected,
    this.chain = 0,
  }) : cells = game.cells.map((c) => c.copy()).toList(),
       affected = {...?affected},
       celebrations = [...game._celebrations],
       effect = game._effect,
       score = game.score,
       moves = game.moves;
}

/// Pure rules engine: the screen replays immutable frames while input is locked.
class SweetGame {
  static const size = 9;
  late List<SweetCell> cells;
  int level, score = 0, moves = 26, randomState;
  int hammers = 3, switches = 2, extraMoves = 1;
  bool won = false, lost = false;
  String id;
  List<SweetFrame> frames = [];
  bool _chocolateHit = false;
  final List<({int index, int radius})> _secondBlasts = [];
  final List<int> _secondColors = [];
  List<int> _celebrations = [];
  SweetEffect _effect = SweetEffect.match;
  SweetGame({
    this.level = 1,
    int seed = 73421,
    int? hammers,
    int? switches,
    int? extraMoves,
  })
    : randomState = seed,
      id = '$seed-$level' {
    this.hammers = hammers ?? 3;
    this.switches = switches ?? 2;
    this.extraMoves = extraMoves ?? 1;
    cells = List.generate(size * size, (i) => SweetCell());
    // New mechanics enter progressively; targets stay visible under the pieces.
    for (var y = 2; y <= 6; y++) {
      for (var x = 2; x <= 6; x++) {
        cells[y * size + x].jelly = level >= 3 ? 2 : 1;
      }
    }
    if (level >= 2) {
      for (final i in [20, 24, 56, 60]) {
        cells[i].frosting = level >= 4 ? 2 : 1;
      }
      for (final i in [30, 32, 48, 50]) {
        cells[i].locked = true;
      }
    }
    if (level >= 3) {
      cells[72].chocolate = true;
      cells[80].chocolate = true;
    }
    if (level >= 4) {
      cells[18].hole = true;
      cells[26].hole = true;
    }
    _fillStable();
    ensureMoves();
    frames.clear();
  }

  int nextInt(int max) {
    randomState = (randomState * 1664525 + 1013904223) & 0xffffffff;
    return (randomState >> 8) % max;
  }

  int get jellyLeft => cells.fold(0, (n, c) => n + c.jelly);
  bool adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < 81 &&
      b < 81 &&
      (a % size - b % size).abs() + (a ~/ size - b ~/ size).abs() == 1;
  List<int> neighbors(int i) => [
    if (i % size > 0) i - 1,
    if (i % size < size - 1) i + 1,
    if (i >= size) i - size,
    if (i < size * (size - 1)) i + size,
  ];

  void _fillStable() {
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      if (!c.playable) continue;
      final forbidden = <int>{};
      if (i % size >= 2 && cells[i - 1].color == cells[i - 2].color) {
        forbidden.add(cells[i - 1].color);
      }
      if (i >= size * 2 && cells[i - size].color == cells[i - size * 2].color) {
        forbidden.add(cells[i - size].color);
      }
      final options = List.generate(
        6,
        (n) => n,
      ).where((n) => !forbidden.contains(n)).toList();
      c.color = options[nextInt(options.length)];
    }
  }

  /// Merge intersecting runs so L/T crosses create one wrapped sweet.
  List<SweetMatch> detect({int? pivot, bool verticalSwipe = false}) {
    final runs = <Set<int>>[];
    for (final horizontal in [true, false]) {
      for (var axis = 0; axis < size; axis++) {
        var run = <int>{};
        var color = -1;
        void finish() {
          if (run.length >= 3) runs.add({...run});
        }

        for (var n = 0; n <= size; n++) {
          final i = n == size
              ? -1
              : horizontal
              ? axis * size + n
              : n * size + axis;
          final value =
              i < 0 ||
                  !cells[i].playable ||
                  cells[i].special == SweetSpecial.bomb
              ? -1
              : cells[i].color;
          if (value < 0 || value != color) {
            finish();
            run = {};
          }
          if (value >= 0) run.add(i);
          color = value;
        }
      }
    }
    final groups = <List<Set<int>>>[];
    for (final run in runs) {
      final touching = groups
          .where((g) => g.any((r) => r.intersection(run).isNotEmpty))
          .toList();
      final group = <Set<int>>[run];
      for (final g in touching) {
        group.addAll(g);
        groups.remove(g);
      }
      groups.add(group);
    }
    return groups.map((g) {
      final all = g.expand((r) => r).toSet();
      final longest = g.map((r) => r.length).reduce(math.max);
      final intersection = g.length > 1 ? g.first.intersection(g[1]) : <int>{};
      final anchor = pivot != null && all.contains(pivot)
          ? pivot
          : intersection.isNotEmpty
          ? intersection.first
          : g.first.elementAt(g.first.length ~/ 2);
      final special = longest >= 5
          ? SweetSpecial.bomb
          : g.length > 1
          ? SweetSpecial.wrapped
          : longest == 4
          ? (verticalSwipe ? SweetSpecial.row : SweetSpecial.column)
          : SweetSpecial.none;
      return SweetMatch(all, anchor, special);
    }).toList();
  }

  void _swap(int a, int b) {
    final color = cells[a].color;
    final special = cells[a].special;
    cells[a].color = cells[b].color;
    cells[a].special = cells[b].special;
    cells[b].color = color;
    cells[b].special = special;
  }

  bool _specialPair(int a, int b) =>
      cells[a].special == SweetSpecial.bomb ||
      cells[b].special == SweetSpecial.bomb ||
      (cells[a].special != SweetSpecial.none &&
          cells[b].special != SweetSpecial.none);
  bool validSwap(int a, int b) {
    if (!adjacent(a, b) || !cells[a].movable || !cells[b].movable) return false;
    if (_specialPair(a, b)) return true;
    _swap(a, b);
    final matched = detect().any(
      (m) => m.cells.contains(a) || m.cells.contains(b),
    );
    _swap(a, b);
    return matched;
  }

  List<int>? get possibleMove {
    for (var i = 0; i < 81; i++) {
      for (final n in neighbors(i).where((n) => n > i)) {
        if (validSwap(i, n)) return [i, n];
      }
    }
    return null;
  }

  void _frame(
    SweetPhase phase,
    String caption, {
    Set<int>? hit,
    int chain = 0,
  }) =>
      frames.add(SweetFrame(this, phase, caption, affected: hit, chain: chain));

  bool move(int a, int b, {bool free = false}) {
    frames = [];
    _effect = SweetEffect.match;
    if (won ||
        lost ||
        !adjacent(a, b) ||
        !cells[a].movable ||
        !cells[b].movable ||
        (free && switches <= 0)) {
      return false;
    }
    final valid = validSwap(a, b);
    _swap(a, b);
    _frame(SweetPhase.swap, '¡A mover las patitas!', hit: {a, b});
    if (!valid && !free) {
      _swap(a, b);
      _frame(
        SweetPhase.input,
        'Sin combinación: conservas el movimiento.',
        hit: {a, b},
      );
      return false;
    }
    if (free) {
      switches--;
    } else {
      moves--;
    }
    _chocolateHit = false;
    if (_specialPair(a, b)) {
      _effect = SweetEffect.fusion;
      _celebrations = [b];
      final hit = _fusion(a, b);
      _clear(hit, chain: 1, caption: '¡Supercombinación de bigotes!');
      _fall();
    }
    _resolve(pivot: b, verticalSwipe: a % size == b % size);
    if (!_chocolateHit && !free && jellyLeft > 0) _growChocolate();
    _finish();
    return true;
  }

  Set<int> _area(int center, int radius) => {
    for (
      var y = math.max(0, center ~/ size - radius);
      y <= math.min(8, center ~/ size + radius);
      y++
    )
      for (
        var x = math.max(0, center % size - radius);
        x <= math.min(8, center % size + radius);
        x++
      )
        y * size + x,
  };
  Set<int> _cross(int i, {int radius = 0}) => {
    for (var n = 0; n < 81; n++)
      if ((n ~/ size - i ~/ size).abs() <= radius ||
          (n % size - i % size).abs() <= radius)
        n,
  };

  Set<int> _fusion(int a, int b) {
    final sa = cells[a].special, sb = cells[b].special;
    final ca = cells[a].color, cb = cells[b].color;
    cells[a].special = SweetSpecial.none;
    cells[b].special = SweetSpecial.none;
    final hit = <int>{a, b};
    if (sa == SweetSpecial.bomb && sb == SweetSpecial.bomb) {
      return Set.from(List.generate(81, (i) => i));
    }
    if (sa == SweetSpecial.bomb || sb == SweetSpecial.bomb) {
      final color = sa == SweetSpecial.bomb ? cb : ca;
      final special = sa == SweetSpecial.bomb ? sb : sa;
      for (var i = 0; i < 81; i++) {
        if (cells[i].playable && cells[i].color == color) {
          if (special == SweetSpecial.wrapped) {
            cells[i].special = SweetSpecial.wrapped;
          } else if (special != SweetSpecial.none) {
            cells[i].special = nextInt(2) == 0
                ? SweetSpecial.row
                : SweetSpecial.column;
          }
          hit.add(i);
        }
      }
      if (special == SweetSpecial.wrapped) {
        final other = cells
            .where(
              (c) =>
                  c.playable && c.color >= 0 && c.color < 6 && c.color != color,
            )
            .map((c) => c.color)
            .toSet()
            .toList();
        if (other.isNotEmpty) {
          final second = other[nextInt(other.length)];
          _secondColors.add(second);
        }
      }
    } else if (sa == SweetSpecial.wrapped && sb == SweetSpecial.wrapped) {
      hit.addAll(_area(b, 2));
      _secondBlasts.add((index: b, radius: 2));
    } else if (sa == SweetSpecial.wrapped || sb == SweetSpecial.wrapped) {
      hit.addAll(_cross(b, radius: 1));
    } else {
      hit.addAll(_cross(b));
    }
    return hit;
  }

  void _clear(
    Set<int> initial, {
    int chain = 1,
    String caption = '¡Ñam! Una combinación',
  }) {
    final hit = {...initial};
    if (_effect == SweetEffect.match) {
      final specials = initial.map((i) => cells[i].special).toSet();
      _effect = specials.contains(SweetSpecial.bomb)
          ? SweetEffect.bomb
          : specials.contains(SweetSpecial.wrapped)
          ? SweetEffect.wrapped
          : specials.any(
              (s) => s == SweetSpecial.row || s == SweetSpecial.column,
            )
          ? SweetEffect.striped
          : SweetEffect.match;
    }
    final triggered = <int>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final i in hit.toList()) {
        if (!triggered.add(i)) continue;
        final c = cells[i];
        Set<int> extra = {};
        switch (c.special) {
          case SweetSpecial.row:
            extra = {for (var x = 0; x < size; x++) i ~/ size * size + x};
          case SweetSpecial.column:
            extra = {for (var y = 0; y < size; y++) y * size + i % size};
          case SweetSpecial.wrapped:
            extra = _area(i, 1);
            _secondBlasts.add((index: i, radius: 1));
          case SweetSpecial.bomb:
            final color = nextInt(6);
            extra = {
              for (var n = 0; n < 81; n++)
                if (cells[n].color == color) n,
            };
          case SweetSpecial.none:
            break;
        }
        final before = hit.length;
        hit.addAll(extra);
        if (hit.length != before) changed = true;
      }
    }
    // A blocker takes at most one layer of damage per explosion wave.
    final damaged = <int>{};
    for (final i in hit) {
      if (cells[i].hole) continue;
      if (cells[i].frosting > 0 || cells[i].chocolate) damaged.add(i);
      if (cells[i].playable) {
        damaged.addAll(
          neighbors(
            i,
          ).where((n) => cells[n].frosting > 0 || cells[n].chocolate),
        );
      }
    }
    _frame(SweetPhase.clear, caption, hit: hit, chain: chain);
    for (final i in hit) {
      final c = cells[i];
      if (!c.playable) continue;
      if (c.jelly > 0) c.jelly--;
      if (c.locked) {
        c.locked = false;
        c.special = SweetSpecial.none;
      } else if (_secondBlasts.any((b) => b.index == i)) {
        c.special = SweetSpecial.none;
      } else {
        c.color = -1;
        c.special = SweetSpecial.none;
      }
      score += 60 * chain;
    }
    for (final i in damaged) {
      final c = cells[i];
      if (c.frosting > 0) c.frosting--;
      if (c.chocolate) {
        c.chocolate = false;
        _chocolateHit = true;
      }
    }
  }

  /// Vertical gravity plus diagonal slides beneath obstacles. Holes never fill.
  void _fall() {
    for (var pass = 0; pass < 81; pass++) {
      var changed = false;
      for (var y = 8; y > 0; y--) {
        for (var x = 0; x < 9; x++) {
          final i = y * size + x;
          if (!cells[i].playable || cells[i].locked || cells[i].color >= 0) {
            continue;
          }
          final sources = [
            i - size,
            if (x > 0) i - size - 1,
            if (x < 8) i - size + 1,
          ];
          for (final from in sources) {
            if (!cells[from].movable) continue;
            final second = _secondBlasts.indexWhere((b) => b.index == from);
            if (second >= 0) {
              final blast = _secondBlasts[second];
              _secondBlasts[second] = (index: i, radius: blast.radius);
            }
            _swap(i, from);
            changed = true;
            break;
          }
        }
      }
      if (!changed) break;
    }
    _frame(SweetPhase.gravity, 'Les damos una patita para bajar');
    // Each disconnected playable chamber has an implicit spawn at its top.
    for (final c in cells) {
      if (c.playable && c.color < 0) c.color = nextInt(6);
    }
    _frame(SweetPhase.spawn, '¡Más premios para los gatitos!');
  }

  void _resolve({int? pivot, bool verticalSwipe = false}) {
    for (var chain = 1; chain <= 100; chain++) {
      if (_secondBlasts.isNotEmpty) {
        final blasts = _secondBlasts.toList();
        _secondBlasts.clear();
        _celebrations = blasts.map((b) => b.index).toList();
        _clear(
          blasts.expand((b) => _area(b.index, b.radius)).toSet(),
          chain: chain,
          caption: '¡Segunda explosión de patitas!',
        );
        _fall();
      }
      if (_secondBlasts.isEmpty && _secondColors.isNotEmpty) {
        final color = _secondColors.removeAt(0);
        final hit = {
          for (var i = 0; i < 81; i++)
            if (cells[i].color == color) i,
        };
        _celebrations = hit.take(1).toList();
        _clear(hit, chain: chain, caption: '¡Un segundo color para Lady!');
        _fall();
      }
      final matches = detect(pivot: pivot, verticalSwipe: verticalSwipe);
      pivot = null;
      if (matches.isEmpty && _secondBlasts.isEmpty && _secondColors.isEmpty) {
        return;
      }
      if (matches.isEmpty) continue;
      _celebrations = matches.map((m) => m.pivot).toList();
      _effect = matches.any((m) => m.special == SweetSpecial.bomb)
          ? SweetEffect.bomb
          : matches.any((m) => m.special == SweetSpecial.wrapped)
          ? SweetEffect.wrapped
          : matches.any((m) => m.special != SweetSpecial.none)
          ? SweetEffect.striped
          : SweetEffect.match;
      _frame(
        SweetPhase.evaluate,
        'Maru y Lady encontraron ${matches.length} combinaciones',
      );
      final created = <int, ({int color, SweetSpecial special})>{};
      final hit = <int>{};
      for (final m in matches) {
        hit.addAll(m.cells);
        if (m.special != SweetSpecial.none && !cells[m.pivot].locked) {
          created[m.pivot] = (color: cells[m.pivot].color, special: m.special);
        }
      }
      _clear(
        hit,
        chain: chain,
        caption: chain > 1
            ? '¡Cascada ×$chain! 🐾'
            : '¡Combinación con bigotes!',
      );
      for (final entry in created.entries) {
        cells[entry.key].color = entry.value.special == SweetSpecial.bomb
            ? 6
            : entry.value.color;
        cells[entry.key].special = entry.value.special;
      }
      if (created.isNotEmpty) {
        final label = _effect == SweetEffect.bomb
            ? '¡5 iguales! Ovillo arcoíris de Lady'
            : _effect == SweetEffect.wrapped
            ? '¡L/T! Regalo explosivo de los gatitos'
            : '¡4 iguales! Rayo de patitas de Maru';
        _frame(
          SweetPhase.enchant,
          label,
          hit: created.keys.toSet(),
          chain: chain,
        );
      }
      _fall();
      _frame(SweetPhase.cascade, '¡A buscar otra combinación!', chain: chain);
    }
    // Bound pathological random cascades while leaving a stable playable board.
    _secondBlasts.clear();
    _secondColors.clear();
    for (final c in cells) {
      if (c.playable) c.special = SweetSpecial.none;
    }
    _fillStable();
  }

  void ensureMoves() {
    if (possibleMove != null) return;
    final slots = [
      for (var i = 0; i < 81; i++)
        if (cells[i].movable) i,
    ];
    for (var attempt = 0; attempt < 100; attempt++) {
      for (var n = slots.length - 1; n > 0; n--) {
        _swap(slots[n], slots[nextInt(n + 1)]);
      }
      if (detect().isEmpty && possibleMove != null) {
        _frame(
          SweetPhase.shuffle,
          '¡Maru mezcla los premios! Sin gastar movimientos.',
        );
        return;
      }
    }
    _fillStable();
    // A color bomb guarantees a playable special interaction, without removing objectives.
    for (final i in slots) {
      if (neighbors(i).any((n) => cells[n].movable)) {
        cells[i].special = SweetSpecial.bomb;
        cells[i].color = 6;
        break;
      }
    }
    _frame(SweetPhase.shuffle, '¡Lady dejó una bomba de regalo!');
  }

  void _growChocolate() {
    final options = <int>{};
    for (var i = 0; i < 81; i++) {
      if (cells[i].chocolate) {
        options.addAll(neighbors(i).where((n) => cells[n].movable));
      }
    }
    if (options.isEmpty) return;
    final i = options.elementAt(nextInt(options.length));
    cells[i].chocolate = true;
    cells[i].color = -1;
    cells[i].special = SweetSpecial.none;
    _frame(
      SweetPhase.spawn,
      '¡El chocolate creció! Combina a su lado.',
      hit: {i},
    );
  }

  void _finish() {
    if (jellyLeft == 0) {
      won = true;
      final spare = moves;
      moves = 0;
      for (var n = 0; n < spare; n++) {
        final options = [
          for (var i = 0; i < 81; i++)
            if (cells[i].movable && cells[i].special == SweetSpecial.none) i,
        ];
        if (options.isEmpty) break;
        final i = options[nextInt(options.length)];
        cells[i].special = nextInt(2) == 0
            ? SweetSpecial.row
            : SweetSpecial.column;
      }
      _frame(
        SweetPhase.victory,
        '¡Fiesta de bigotes! $spare movimientos de regalo',
      );
      for (var wave = 0; wave < 20; wave++) {
        final specials = {
          for (var i = 0; i < 81; i++)
            if (cells[i].special != SweetSpecial.none) i,
        };
        if (specials.isEmpty) break;
        _celebrations = specials.take(3).toList();
        _clear(specials, caption: '¡Lluvia de premios!');
        _fall();
        _resolve();
      }
      _frame(
        SweetPhase.victory,
        '¡Nivel superado! Maru y Lady celebran contigo',
      );
    } else if (moves <= 0) {
      lost = true;
      _frame(SweetPhase.defeat, 'Nos faltó un poquito. ¡Otra oportunidad!');
    } else {
      ensureMoves();
      _frame(SweetPhase.input, 'Combina premios y limpia la gelatina');
    }
  }

  bool hammer(int i) {
    frames = [];
    if (won || lost || hammers <= 0 || i < 0 || i >= 81 || cells[i].hole) {
      return false;
    }
    hammers--;
    _celebrations = [i];
    _clear({i}, caption: '¡Martillazo de patita!');
    _fall();
    _resolve();
    _finish();
    return true;
  }

  bool addMoves() {
    if (won || extraMoves <= 0) return false;
    extraMoves--;
    moves += 5;
    lost = false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'cells': cells.map((c) => c.toJson()).toList(),
    'level': level,
    'score': score,
    'moves': moves,
    'rng': randomState,
    'id': id,
    'hammers': hammers,
    'switches': switches,
    'extra': extraMoves,
    'won': won,
    'lost': lost,
  };
  factory SweetGame.fromJson(Map<String, dynamic> j) {
    final game = SweetGame(level: j['level'] as int, seed: j['rng'] as int);
    game.cells = (j['cells'] as List)
        .map((c) => SweetCell.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    if (game.cells.length != 81 ||
        game.cells.any(
          (c) => c.color < -1 || c.color > 6 || c.jelly < 0 || c.jelly > 2,
        )) {
      throw const FormatException('Invalid sweet board');
    }
    game.score = j['score'] as int;
    game.moves = j['moves'] as int;
    game.randomState = j['rng'] as int;
    game.id = j['id'] as String;
    game.hammers = j['hammers'] as int;
    game.switches = j['switches'] as int;
    game.extraMoves = j['extra'] as int;
    game.won = j['won'] as bool;
    game.lost = j['lost'] as bool;
    return game;
  }
}
