import 'paw_background.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cat_character.dart';
import 'store.dart';
import 'game_audio.dart';

// Accents are omitted for typing; Ñ remains a separate letter.
const _words = <String>[
  'GATOS',
  'PATAS',
  'MIMOS',
  'JUGAR',
  'AMIGA',
  'AMIGO',
  'BESOS',
  'FELIZ',
  'DULCE',
  'NUBES',
  'LUNAS',
  'SOLAR',
  'PLAYA',
  'CAMPO',
  'VERDE',
  'ROSAS',
  'FLORA',
  'ARBOL',
  'FRUTA',
  'FRESA',
  'MANGO',
  'LIMON',
  'MELON',
  'PERAS',
  'QUESO',
  'CREMA',
  'LECHE',
  'PLATO',
  'TAZAS',
  'HORNO',
  'FUEGO',
  'AGUAS',
  'NIEVE',
  'BRISA',
  'CALOR',
  'RELOJ',
  'LIBRO',
  'PAPEL',
  'NOTAS',
  'LAPIZ',
  'LETRA',
  'FRASE',
  'CANTO',
  'BAILE',
  'PIANO',
  'RADIO',
  'RITMO',
  'PASOS',
  'SALTO',
  'CORRE',
  'RATON',
  'PERRO',
  'CABRA',
  'TIGRE',
  'CEBRA',
  'OVEJA',
  'MOSCA',
  'ABEJA',
  'PECES',
  'PLUMA',
  'NIDOS',
  'COLAS',
  'GARZA',
  'BUHOS',
  'SELVA',
  'MONTE',
  'VALLE',
  'CUEVA',
  'PISTA',
  'CALLE',
  'CASAS',
  'TECHO',
  'SILLA',
  'MESAS',
  'COCHE',
  'BARCO',
  'AVION',
  'VIAJE',
  'MAPAS',
  'NORTE',
  'SURCO',
  'SUEÑO',
  'NIÑOS',
  'NIÑAS',
  'AÑEJO',
  'MAÑAS',
  'SEÑAL',
  'DUEÑO',
  'PAÑOS',
  'BAÑOS',
  'CIELO',
  'MUNDO',
  'HOGAR',
  'NOCHE',
  'TARDE',
  'ENERO',
  'MARZO',
  'ABRIL',
  'JUNIO',
  'JULIO',
  'SALUD',
  'MAGIA',
  'CALMA',
  'GANAS',
  'RISAS',
  'IDEAS',
  'UNION',
  'CERCA',
  'LEJOS',
  'NUEVO',
  'VIEJO',
  'LARGO',
  'CORTO',
  'ANCHO',
  'SUAVE',
  'BELLO',
  'LINDA',
  'LINDO',
  'BUENO',
  'BUENA',
  'LISTO',
  'LISTA',
  'LENTO',
  'RUBIO',
  'NEGRO',
  'BLUSA',
  'FALDA',
  'BOTAS',
  'GORRO',
  'BOLSA',
  'CAJAS',
  'SOBRE',
  'CARTA',
  'MONOS',
  'REINA',
  'REYES',
  'TORRE',
  'METRO',
  'CINCO',
  'SIETE',
  'NUEVE',
  'DOBLE',
  'MITAD',
  'PRIMO',
  'PRIMA',
  'MADRE',
  'PADRE',
  'PUNTO',
  'LINEA',
  'BORDE',
  'FORMA',
  'COLOR',
  'GRANO',
  'TRIGO',
  'ARROZ',
  'PASTA',
  'PANES',
  'SOPAS',
  'HUEVO',
  'POLLO',
  'CARNE',
  'SALSA',
  'ROCAS',
  'ARENA',
  'OLIVA',
  'PINOS',
  'RAMAS',
  'HOJAS',
  'BROTE',
];
const _chileanWords = [
  'POLOLO',
  'POLOLA',
  'PALTA',
  'FOME',
  'FOMES',
  'BACAN',
  'PEUCO',
  'GUATA',
  'QUINA',
  'LUCHA',
  'LUCAS',
  'PISCO',
  'CHUPE',
  'MOTES',
  'YAPAS',
  'LACHO',
  'CHATO',
  'PIOLA',
  'PEGA',
  'PEGAS',
  'CABRO',
  'CABRA',
  'CHALA',
  'CUECA',
  'ÑUBLE',
];
String normalizeWordle(String word) => word
    .trim()
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll('Ü', 'U');
final _dictionary = {
  ..._words,
  ..._chileanWords,
}.where((w) => w.length == 5).toSet();

// Hunspell validates guesses, but includes rare words unsuitable as answers.
// Keep the answer pool curated independently of the loaded dictionaries.
final wordleAnswers = Set<String>.unmodifiable({
  ..._words,
  'PALTA',
  'FOMES',
  'BACAN',
  'GUATA',
  'LUCAS',
  'PISCO',
  'CHATO',
  'PIOLA',
  'PEGAS',
  'CABRO',
  'CHALA',
  'CUECA',
});

String _pickAnswer([String? previous]) {
  final choices = wordleAnswers.where((word) => word != previous).toList();
  return choices[Random().nextInt(choices.length)];
}

/// First reserve exact matches, then consume remaining copies of each letter.
List<int> wordleMarks(String guess, String answer) {
  final marks = List.filled(5, 0);
  final remaining = <String, int>{};
  for (var i = 0; i < 5; i++) {
    if (guess[i] == answer[i]) {
      marks[i] = 2;
    } else {
      remaining.update(answer[i], (n) => n + 1, ifAbsent: () => 1);
    }
  }
  for (var i = 0; i < 5; i++) {
    if (marks[i] == 2) continue;
    if ((remaining[guess[i]] ?? 0) > 0) {
      marks[i] = 1;
      remaining[guess[i]] = remaining[guess[i]]! - 1;
    }
  }
  return marks;
}

class WordleScreen extends StatefulWidget {
  final GameStore store;
  const WordleScreen({super.key, required this.store});
  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _reaction;
  String _mood = 'idle';
  bool _loading = true;
  String? _dictionaryError;
  String _roundId = DateTime.now().microsecondsSinceEpoch.toString();
  List<int> _hints = [];
  String _hintDay = '';
  int _hintsUsed = 0;
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int get _remainingHints => _hintDay == _today ? 2 - _hintsUsed : 2;
  late String _answer;
  List<String> _guesses = [];
  String _input = '';
  String _message = 'Maru y Lady te acompañan: ¡encuentra la palabra!';
  int _wins = 0;
  bool get _won => _guesses.contains(_answer);
  bool get _finished => _won || _guesses.length == 6;

  @override
  void initState() {
    super.initState();
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loadDictionary();
  }

  Future<void> _loadDictionary() async {
    try {
      for (final asset in ['assets/wordle_es.dic', 'assets/wordle_cl.dic']) {
        final raw = await rootBundle.loadString(asset);
        for (final line in const LineSplitter().convert(raw)) {
          final word = normalizeWordle(line.split('/').first);
          if (RegExp(r'^[A-ZÑ]{5}$').hasMatch(word)) _dictionary.add(word);
        }
      }
    } catch (_) {
      _dictionaryError = 'No se pudo cargar el diccionario ampliado.';
    }
    if (!mounted) return;
    _answer = _pickAnswer();
    try {
      final raw = widget.store.prefs.getString('wordle.v1');
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        _wins = saved['wins'] as int? ?? 0;
        final answer = saved['answer'] as String;
        final guesses = List<String>.from(saved['guesses'] as List);
        if (wordleAnswers.contains(answer) &&
            guesses.length <= 6 &&
            guesses.every(_dictionary.contains)) {
          _answer = answer;
          _guesses = guesses;
          _roundId = saved['roundId'] as String? ?? _roundId;
          _hints = List<int>.from(
            saved['hints'] ?? [],
          ).where((i) => i >= 0 && i < 5).toSet().toList();
        }
      }
    } catch (_) {
      /* A damaged save starts a fresh puzzle. */
    }
    if (_finished) _message = _result;
    _hintDay = widget.store.prefs.getString('wordle.hintDay') ?? '';
    _hintsUsed = (widget.store.prefs.getInt('wordle.hintsUsed') ?? 0).clamp(
      0,
      2,
    );
    await _save();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String get _result => _won
      ? '¡Acertaste en ${_guesses.length}/6! +100 monedas 🪙'
      : 'La palabra era $_answer. ¡Vamos por otra!';

  Future<void> _save() async {
    final ok = await widget.store.prefs.setString(
      'wordle.v1',
      jsonEncode({
        'answer': _answer,
        'guesses': _guesses,
        'wins': _wins,
        'roundId': _roundId,
        'hints': _hints,
      }),
    );
    if (!ok && mounted) {
      setState(() => _message = 'No se pudo guardar la partida.');
    }
  }

  void _key(String key) {
    _focus.requestFocus();
    if (_finished || _loading) return;
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (key == 'ENVIAR') {
        if (_input.length != 5) {
          _message = 'Completa las cinco letras.';
          return;
        }
        if (!_dictionary.contains(_input)) {
          _message = 'Esa palabra no está en nuestro vocabulario todavía.';
          _react('wrong');
          return;
        }
        final marks = wordleMarks(_input, _answer);
        _guesses.add(_input);
        _input = '';
        if (_won) {
          _wins++;
          widget.store.rewardWordle(_roundId);
        }
        _react(
          _won
              ? 'win'
              : marks.any((m) => m > 0)
              ? 'close'
              : 'wrong',
        );
        _message = _finished ? _result : '¡Sigue las pistas de colores!';
        GameAudio.instance.play(_won ? GameSfx.reveal : GameSfx.place);
        if (_won) GameAudio.instance.play(GameSfx.kitten);
        HapticFeedback.lightImpact();
        _save();
      } else if (_input.length < 5 && RegExp(r'^[A-ZÑ]$').hasMatch(key)) {
        _input += key;
      }
    });
  }

  void _newGame() {
    setState(() {
      _answer = _pickAnswer(_answer);
      _guesses = [];
      _roundId = DateTime.now().microsecondsSinceEpoch.toString();
      _hints = [];
      _mood = 'idle';
      _input = '';
      _message = '¡Otra palabra para nuestros bigotes!';
    });
    _save();
    _focus.requestFocus();
  }

  void _react(String mood) {
    _mood = mood;
    _reaction.forward(from: 0);
  }

  Future<void> _hint() async {
    if (_loading || _finished || _remainingHints <= 0) return;
    final candidates = List.generate(5, (i) => i)
        .where(
          (i) =>
              !_hints.contains(i) && !_guesses.any((g) => g[i] == _answer[i]),
        )
        .toList();
    if (candidates.isEmpty) {
      setState(() => _message = '¡Ya conoces todas las posiciones!');
      return;
    }
    final index = candidates[Random().nextInt(candidates.length)];
    setState(() {
      if (_hintDay != _today) {
        _hintDay = _today;
        _hintsUsed = 0;
      }
      _hintsUsed++;
      _hints.add(index);
      _message = 'Lady dice: la letra ${index + 1} es ${_answer[index]}.';
      _react('close');
    });
    await widget.store.prefs.setString('wordle.hintDay', _hintDay);
    await widget.store.prefs.setInt('wordle.hintsUsed', _hintsUsed);
    await _save();
  }

  Widget _animatedCat(CatKind cat) => AnimatedBuilder(
    animation: _reaction,
    builder: (context, _) {
      final t = _reaction.value;
      final running = _reaction.isAnimating;
      final side = cat == CatKind.maru ? -1.0 : 1.0;
      final wave = sin(t * pi * (_mood == 'win' ? 6 : 4));
      final bounce = running && _mood != 'wrong'
          ? -wave.abs() * (_mood == 'win' ? 20 : 8)
          : 0.0;
      final shake = running && _mood == 'wrong' ? wave * 7 : 0.0;
      return Transform.translate(
        offset: Offset(shake, bounce),
        child: Transform.rotate(
          angle: running ? wave * side * .18 : 0,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CatActor(
                cat: cat,
                size: 58,
                action: CatAction.blocks,
                active: running && _mood != 'wrong',
                crying: running && _mood == 'wrong',
                showLabel: false,
              ),
              if (running)
                Text(
                  _mood == 'win'
                      ? '✨💛'
                      : _mood == 'close'
                      ? '💡'
                      : '💭',
                  style: const TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _reaction.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wordlady'),
          actions: const [AudioSettingsButton()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    const colors = [Color(0xff667078), Color(0xffb88723), Color(0xff348767)];
    final keyboard = <String, int>{};
    for (final guess in _guesses) {
      final marks = wordleMarks(guess, _answer);
      for (var i = 0; i < 5; i++) {
        keyboard[guess[i]] = max(keyboard[guess[i]] ?? -1, marks[i]);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wordlady'),
        actions: const [AudioSettingsButton()],
      ),
      body: PawBackground(child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _key('ENVIAR');
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _key('⌫');
          } else {
            final letter = (event.character ?? '')
                .toUpperCase()
                .replaceAll('Á', 'A')
                .replaceAll('É', 'E')
                .replaceAll('Í', 'I')
                .replaceAll('Ó', 'O')
                .replaceAll('Ú', 'U')
                .replaceAll('Ü', 'U');
            if (!RegExp(r'^[A-ZÑ]$').hasMatch(letter)) {
              return KeyEventResult.ignored;
            }
            _key(letter);
          }
          return KeyEventResult.handled;
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileSize = ((constraints.maxHeight - 355) / 6).clamp(
                    32.0,
                    58.0,
                  );
                  return ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _animatedCat(CatKind.maru),
                          Expanded(
                            child: Text(
                              '5 letras · 6 intentos\n$_wins victorias · ${widget.store.coins} 🪙',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _animatedCat(CatKind.lady),
                        ],
                      ),
                      const Text(
                        'Sin tildes; la Ñ sí cuenta. Verde: posición correcta.\nAmarillo: otra posición. Gris: no aparece.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (_dictionaryError != null)
                        Text(_dictionaryError!, textAlign: TextAlign.center),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _finished || _remainingHints <= 0
                                ? null
                                : _hint,
                            icon: const Icon(Icons.lightbulb_outline, size: 18),
                            label: Text('Pista ($_remainingHints/2 hoy)'),
                          ),
                          if (_hints.isNotEmpty)
                            Flexible(
                              child: Text(
                                _hints
                                    .map((i) => '${i + 1}: ${_answer[i]}')
                                    .join(' · '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (var row = 0; row < 6; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var col = 0; col < 5; col++)
                                Flexible(
                                  child: AnimatedContainer(
                                    duration: Duration(
                                      milliseconds: 250 + col * 75,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: tileSize,
                                    ),
                                    decoration: BoxDecoration(
                                      color: row < _guesses.length
                                          ? colors[wordleMarks(
                                              _guesses[row],
                                              _answer,
                                            )[col]]
                                          : Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xffb5bdb6),
                                      ),
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Center(
                                        child: Text(
                                          row < _guesses.length
                                              ? _guesses[row][col]
                                              : row == _guesses.length &&
                                                    col < _input.length
                                              ? _input[col]
                                              : '',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: row < _guesses.length
                                                ? Colors.white
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (_finished)
                        FilledButton.icon(
                          onPressed: _newGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Otra palabra'),
                        ),
                      for (final keys in [
                        'QWERTYUIOP'.split(''),
                        'ASDFGHJKLÑ'.split(''),
                        ['ENVIAR', ...'ZXCVBNM'.split(''), '⌫'],
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              for (final key in keys)
                                Expanded(
                                  flex: key.length > 1 ? 2 : 1,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Semantics(
                                      button: true,
                                      label: key == '⌫' ? 'Borrar letra' : key,
                                      child: Material(
                                        color: keyboard.containsKey(key)
                                            ? colors[keyboard[key]!]
                                            : const Color(0xffe3e8e1),
                                        borderRadius: BorderRadius.circular(7),
                                        child: InkWell(
                                          onTap: _finished
                                              ? null
                                              : () => _key(key),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          child: SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: Text(
                                                key,
                                                style: TextStyle(
                                                  fontSize: key.length > 1
                                                      ? 10
                                                      : 15,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      keyboard.containsKey(key)
                                                      ? Colors.white
                                                      : const Color(0xff293f39),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      )),
    );
  }
}
