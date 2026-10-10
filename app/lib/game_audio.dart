import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_settings_panel.dart';

enum GameSfx {
  kitten('kitten.mp3', .62, 1500),
  paper('paper.wav', .55, 300),
  reveal('reveal.wav', .55, 500),
  marusCardVictory('marus_card_victory.mp3', .7, 1000),
  marusLauncher('marus_launcher.wav', .26, 120),
  marusHarvest('marus_harvest.wav', .50, 100),
  marusBite('marus_bite.wav', .22, 260),
  marusArmor('marus_armor.wav', .38, 100),
  marusDefeat('marus_defeat.wav', .30, 220),
  place('place.wav', .35, 90),
  clear('clear.wav', .48, 180),
  coin('coin.wav', .35, 100),
  jump('jump.wav', .22, 220),
  spring('spring.wav', .42, 500),
  rocket('rocket.wav', .4, 700),
  abduction('abduction.wav', .45, 1000);

  final String file;
  final double gain;
  final int cooldownMs;
  const GameSfx(this.file, this.gain, this.cooldownMs);
}

/// Four dedicated combat voices; no unbounded queue or delayed sonic backlog.
class CombatVoiceRequest {
  const CombatVoiceRequest(this.slot, this.effect, this.rate, this.gain);
  final int slot;
  final GameSfx effect;
  final double rate, gain;
  String get asset => rate == 1
      ? effect.file
      : effect.file.replaceFirst('.wav', rate < 1 ? '_low.wav' : '_high.wav');
}

class CombatSfxLimiter {
  CombatSfxLimiter({math.Random? random}) : random = random ?? math.Random();
  final math.Random random;
  final _ends = List<int>.filled(4, 0);
  final _priorities = List<int>.filled(4, -1);
  final _last = <GameSfx, int>{};
  final _starts = <int>[];
  static const priorities = {
    GameSfx.marusLauncher: 0,
    GameSfx.marusBite: 1,
    GameSfx.marusArmor: 2,
    GameSfx.marusDefeat: 3,
    GameSfx.marusHarvest: 4,
  };
  static const durations = {
    GameSfx.marusLauncher: 293,
    GameSfx.marusHarvest: 351,
    GameSfx.marusBite: 273,
    GameSfx.marusArmor: 243,
    GameSfx.marusDefeat: 779,
  };
  List<CombatVoiceRequest> select(
    Iterable<GameSfx> events,
    int now, {
    bool audible = true,
  }) {
    if (!audible) {
      reset();
      return const [];
    }
    _starts.removeWhere((t) => now - t >= 1000);
    final ordered = events.where(priorities.containsKey).toSet().toList()
      ..sort((a, b) => priorities[b]!.compareTo(priorities[a]!));
    final accepted = <CombatVoiceRequest>[];
    for (final cue in ordered) {
      if (accepted.length >= 2 || _starts.length >= 10) break;
      if (now - (_last[cue] ?? -10000) < cue.cooldownMs) continue;
      var slot = _ends.indexWhere((end) => end <= now);
      if (slot < 0) {
        slot = 0;
        for (var i = 1; i < 4; i++) {
          if (_priorities[i] < _priorities[slot]) slot = i;
        }
        if (_priorities[slot] >= priorities[cue]!) continue;
      }
      final rate = const [.97, 1.0, 1.03][random.nextInt(3)];
      final gain = cue.gain * (.92 + random.nextDouble() * .16);
      _ends[slot] = now + (durations[cue]! / rate).ceil() + 40;
      _priorities[slot] = priorities[cue]!;
      _last[cue] = now;
      _starts.add(now);
      accepted.add(CombatVoiceRequest(slot, cue, rate, gain));
    }
    return accepted;
  }

  void reset() {
    _ends.fillRange(0, 4, 0);
    _priorities.fillRange(0, 4, -1);
    _last.clear();
    _starts.clear();
  }
}

class _CombatVoice {
  final player = AudioPlayer();
  int revision = 0;
  double gain = 0;
  Future<void> queue = Future.value();
}

/// Local assets, independent SFX/music volumes, and cancellable music fades.
/// No audio objects are created until the app initializes and receives a tap.
class GameAudio with WidgetsBindingObserver {
  static final instance = GameAudio();
  final changes = ValueNotifier(0);
  final meows = MeowRotation();
  SharedPreferences? _prefs;
  final Map<GameSfx, AudioPlayer> _effects = {};
  final _combatLimiter = CombatSfxLimiter();
  final _combatVoices = <int, _CombatVoice>{};
  final Map<GameSfx, int> _lastEffect = {};
  final Map<String, List<String>> _tracks = {};
  final Map<String, int> _trackIndex = {};
  final Set<AudioPlayer> _musicPlayers = {};
  final Stopwatch _clock = Stopwatch()..start();
  AudioPlayer? _music;
  String? _musicAsset;
  String _scene = 'menu';
  double _currentGain = 0;
  int _revision = 0;
  bool _unlocked = false, _background = false, _paused = false;
  bool effectsEnabled = true, musicEnabled = true;
  double effectsVolume = .8, musicVolume = .3;
  Future<void> _musicQueue = Future.value();

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    effectsEnabled = prefs.getBool('audio.effects') ?? true;
    musicEnabled = prefs.getBool('audio.music') ?? true;
    effectsVolume = (prefs.getDouble('audio.effectsVolume') ?? .8).clamp(0, 1);
    musicVolume = (prefs.getDouble('audio.musicVolume') ?? .3).clamp(0, 1);
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      await _safe(
        () => AudioPlayer.global.setAudioContext(
          AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
        ),
      );
    }
    try {
      final manifest =
          jsonDecode(
                await rootBundle.loadString('assets/audio/music/tracks.json'),
              )
              as Map<String, dynamic>;
      for (final entry in manifest.entries) {
        final values = entry.value is List
            ? (entry.value as List).whereType<String>().toList()
            : entry.value is String && (entry.value as String).isNotEmpty
            ? [entry.value as String]
            : <String>[];
        if (values.isNotEmpty) {
          _tracks[entry.key] = [
            for (final value in values) 'audio/music/$value',
          ];
          _trackIndex[entry.key] = math.Random().nextInt(values.length);
        }
      }
    } catch (_) {
      // Music is optional until the user supplies their tracks.
    }
  }

  void unlock() {
    if (_prefs == null || _unlocked) return;
    _unlocked = true;
    play(GameSfx.place);
    _queueMusic();
  }

  bool get combatAudible =>
      _prefs != null &&
      _unlocked &&
      effectsEnabled &&
      effectsVolume > 0 &&
      !_background &&
      !_paused;

  void playCombat(Iterable<GameSfx> events) {
    final requests = _combatLimiter.select(
      events,
      _clock.elapsedMilliseconds,
      audible: combatAudible,
    );
    for (final r in requests) {
      final v = _combatVoices.putIfAbsent(r.slot, _CombatVoice.new);
      final revision = ++v.revision;
      v.gain = r.gain;
      v.queue = v.queue.then(
        (_) => _safe(() async {
          if (revision != v.revision || !combatAudible) return;
          await v.player.stop();
          await v.player.setReleaseMode(ReleaseMode.stop);
          await v.player.setSource(AssetSource('audio/${r.asset}'));
          // Pitch is baked into the short variant; browser preservePitch cannot undo it.
          await _safe(() => v.player.setPlaybackRate(1));
          if (revision != v.revision || !combatAudible) return;
          await v.player.setVolume((effectsVolume * r.gain).clamp(0, 1));
          if (revision != v.revision || !combatAudible) return;
          await v.player.resume();
        }),
      );
    }
  }

  void stopCombat() {
    _combatLimiter.reset();
    for (final v in _combatVoices.values) {
      v.revision++;
      v.queue = v.queue.then((_) => _safe(v.player.stop));
    }
  }

  void play(GameSfx effect) {
    if (CombatSfxLimiter.priorities.containsKey(effect)) {
      playCombat([effect]);
      return;
    }

    if (_prefs == null ||
        !_unlocked ||
        !effectsEnabled ||
        effectsVolume <= 0 ||
        _background ||
        _paused) {
      return;
    }
    final now = _clock.elapsedMilliseconds;
    if (now - (_lastEffect[effect] ?? -10000) < effect.cooldownMs) return;
    _lastEffect[effect] = now;
    unawaited(
      _safe(() async {
        final player = _effects.putIfAbsent(effect, AudioPlayer.new);
        await player.play(
          AssetSource(
            'audio/${effect == GameSfx.kitten ? meows.next() : effect.file}',
          ),
          volume: effectsVolume * effect.gain,
        );
      }),
    );
  }

  void stopEffect(GameSfx effect) {
    final player = _effects[effect];
    if (player != null) unawaited(_safe(player.stop));
  }

  void enter(String scene) {
    if (_scene == scene) return;
    stopCombat();
    _scene = scene;
    _paused = false;
    for (final player in _effects.values) {
      unawaited(_safe(player.stop));
    }
    _queueMusic();
  }

  /// Skip the current song and start the next one in this scene's rotation.
  void skipMusic() {
    final list = _tracks[_scene];
    if (list == null || list.length < 2) return;
    _trackIndex[_scene] = ((_trackIndex[_scene] ?? 0) + 1) % list.length;
    _musicAsset = null;
    _queueMusic();
  }

  void pauseGame(bool paused) {
    _paused = paused;
    if (paused) _silenceNow();
    _queueMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) _silenceNow();
    _queueMusic();
  }

  void _silenceNow() {
    stopCombat();
    for (final player in [..._effects.values, ..._musicPlayers]) {
      unawaited(_safe(player.pause));
    }
  }

  void configure({
    bool? effects,
    bool? music,
    double? sfxGain,
    double? musicGain,
  }) {
    final musicStateChanged = music != null && music != musicEnabled;
    effectsEnabled = effects ?? effectsEnabled;
    musicEnabled = music ?? musicEnabled;
    effectsVolume = (sfxGain ?? effectsVolume).clamp(0, 1);
    musicVolume = (musicGain ?? musicVolume).clamp(0, 1);
    if (!effectsEnabled || effectsVolume <= 0) {
      stopCombat();
      for (final player in _effects.values) {
        unawaited(_safe(player.stop));
      }
    } else {
      for (final entry in _effects.entries) {
        unawaited(
          _safe(() => entry.value.setVolume(effectsVolume * entry.key.gain)),
        );
      }
    }
    for (final v in _combatVoices.values) {
      unawaited(
        _safe(() => v.player.setVolume((effectsVolume * v.gain).clamp(0, 1))),
      );
    }
    // Changing a slider must never restart or crossfade the current song.
    // Update the active player directly and preserve its playback position.
    if (musicGain != null && _music != null && musicEnabled) {
      _currentGain = musicVolume;
      unawaited(_safe(() => _music!.setVolume(musicVolume)));
    }
    unawaited(
      _safe(() async {
        await _prefs?.setBool('audio.effects', effectsEnabled);
        await _prefs?.setBool('audio.music', musicEnabled);
        await _prefs?.setDouble('audio.effectsVolume', effectsVolume);
        await _prefs?.setDouble('audio.musicVolume', musicVolume);
      }),
    );
    changes.value++;
    if (musicStateChanged) _queueMusic();
  }

  void _queueMusic() {
    final revision = ++_revision;
    if (_prefs == null || !_unlocked) return;
    final list = _tracks[_scene];
    final asset = musicEnabled && !_background && !_paused && list != null
        ? list[_trackIndex[_scene] ?? 0]
        : null;
    // Serial transitions plus revision checks prevent an old screen from
    // starting its music after a faster navigation has already selected another.
    _musicQueue = _musicQueue.then(
      (_) => _safe(() => _crossfade(asset, revision)),
    );
  }

  Future<void> _crossfade(String? asset, int revision) async {
    if (revision != _revision) return;
    final previous = _music;
    if (asset == null && previous == null) return;
    final startGain = _currentGain;
    if (asset == _musicAsset && previous != null) {
      await previous.resume();
      for (var i = 1; i <= 12 && revision == _revision; i++) {
        _currentGain = startGain + (musicVolume - startGain) * i / 12;
        await previous.setVolume(_currentGain);
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }
      return;
    }
    AudioPlayer? next;
    var promoted = false;
    try {
      if (asset != null) {
        next = AudioPlayer();
        _musicPlayers.add(next);
        await next.setReleaseMode(
          _tracks[_scene]?.length == 1 ? ReleaseMode.loop : ReleaseMode.stop,
        );
        final player = next;
        player.onPlayerComplete.listen((_) {
          if (_music != player) return;
          final list = _tracks[_scene];
          if (list == null || list.length < 2) return;
          _trackIndex[_scene] = ((_trackIndex[_scene] ?? 0) + 1) % list.length;
          _musicAsset = null;
          _queueMusic();
        });
        await next.play(AssetSource(asset), volume: 0);
      }
      for (var i = 1; i <= 20; i++) {
        if (revision != _revision) return;
        final t = i / 20;
        _currentGain = startGain * (1 - t);
        await previous?.setVolume(_currentGain);
        await next?.setVolume(musicVolume * t);
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }
      await previous?.dispose();
      _musicPlayers.remove(previous);
      _music = next;
      _musicAsset = asset;
      _currentGain = next == null ? 0 : musicVolume;
      promoted = true;
    } finally {
      if (!promoted && next != null) {
        _musicPlayers.remove(next);
        await next.dispose();
      }
    }
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Audio unavailable: $error');
    }
  }
}

class GameAudioRouteObserver extends NavigatorObserver {
  static const scenes = {
    '/': 'menu',
    '/blocks': 'blocks',
    '/wordle': 'wordle',
    '/sweet': 'sweet',
    '/leap': 'leap',
  };
  void _select(Route<dynamic>? route) {
    final scene = scenes[route?.settings.name];
    if (scene != null) GameAudio.instance.enter(scene);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _select(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _select(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _select(newRoute);
}

class AudioSettingsButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onOpen, onClose;
  const AudioSettingsButton({super.key, this.color, this.onOpen, this.onClose});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: GameAudio.instance.changes,
    builder: (context, _, child) => IconButton(
      tooltip: 'Sonido y música',
      icon: Icon(
        GameAudio.instance.effectsEnabled || GameAudio.instance.musicEnabled
            ? Icons.volume_up_rounded
            : Icons.volume_off_rounded,
        color: color,
      ),
      onPressed: () async {
        onOpen?.call();
        await showDialog<void>(
          context: context,
          builder: (context) => AudioSettingsPanel(audio: GameAudio.instance),
        );
        onClose?.call();
      },
    ),
  );
}

/// Shuffle bag: all recordings are heard before reusing one, without repeats
/// at the boundary between two bags.
class MeowRotation {
  static const assets = [
    'kitten.mp3',
    'meow_tuber.mp3',
    'meow_gurdy.mp3',
    'meow_kitten_a.mp3',
    'meow_kitten_b.mp3',
    'meow_kitten_c.mp3',
    'meow_kitten_d.mp3',
  ];
  final math.Random random;
  final List<String> _bag = [];
  String? _previous;
  MeowRotation({math.Random? random}) : random = random ?? math.Random();
  String next() {
    if (_bag.isEmpty) {
      _bag.addAll(assets);
      _bag.shuffle(random);
      if (_bag.last == _previous) {
        final first = _bag.removeAt(0);
        _bag.add(first);
      }
    }
    return _previous = _bag.removeLast();
  }
}
