import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameSfx {
  kitten('kitten.mp3', .62, 1500),
  paper('paper.wav', .55, 300),
  reveal('reveal.wav', .55, 500),
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

/// Local assets, independent SFX/music volumes, and cancellable music fades.
/// No audio objects are created until the app initializes and receives a tap.
class GameAudio with WidgetsBindingObserver {
  static final instance = GameAudio();
  final changes = ValueNotifier(0);
  SharedPreferences? _prefs;
  final Map<GameSfx, AudioPlayer> _effects = {};
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

  void play(GameSfx effect) {
    if (_prefs == null ||
        !_unlocked ||
        !effectsEnabled ||
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
          AssetSource('audio/${effect.file}'),
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
    if (!effectsEnabled) {
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
        await next.setReleaseMode(ReleaseMode.stop);
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
          builder: (context) => AlertDialog(
            title: const Text('Sonido y música'),
            content: SizedBox(
              width: 300,
              child: ValueListenableBuilder(
                valueListenable: GameAudio.instance.changes,
                builder: (context, _, child) {
                  final audio = GameAudio.instance;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gatitos y efectos'),
                        value: audio.effectsEnabled,
                        onChanged: (v) => audio.configure(effects: v),
                      ),
                      Slider(
                        label: '${(audio.effectsVolume * 100).round()} %',
                        value: audio.effectsVolume,
                        onChanged: audio.effectsEnabled
                            ? (v) => audio.configure(sfxGain: v)
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: audio.musicEnabled
                              ? audio.skipMusic
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Siguiente canción'),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Música de fondo'),
                        value: audio.musicEnabled,
                        onChanged: (v) => audio.configure(music: v),
                      ),
                      Slider(
                        label: '${(audio.musicVolume * 100).round()} %',
                        value: audio.musicVolume,
                        onChanged: audio.musicEnabled
                            ? (v) => audio.configure(musicGain: v)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              ),
            ],
          ),
        );
        onClose?.call();
      },
    ),
  );
}
