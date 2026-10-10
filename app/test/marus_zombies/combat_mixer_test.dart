import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/game_audio.dart';

class _Cache extends AudioCache {
  @override
  Future<String> loadPath(String name) async => '/audio-test/$name';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native mixer honors zero volume, mute, pause, lifecycle and card voice isolation',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      const codec = StandardMethodCodec();
      const methods = MethodChannel('xyz.luan/audioplayers');
      const global = MethodChannel('xyz.luan/audioplayers.global');
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(global, (_) async => null);
      const events = MethodChannel('xyz.luan/audioplayers.global/events');
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        final args = (call.arguments as Map).cast<String, dynamic>();
        final id = args['playerId'] as String;
        final channel = MethodChannel('xyz.luan/audioplayers/events/$id');
        if (call.method == 'create') {
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        if (call.method == 'setSourceUrl') {
          // Emulate the native prepared event; no speaker or decoder in this test.
          await messenger.handlePlatformMessage(
            channel.name,
            codec.encodeSuccessEnvelope({
              'event': 'audio.onPrepared',
              'value': true,
            }),
            (_) {},
          );
        }
        if (call.method == 'getDuration') return 500;
        if (call.method == 'getCurrentPosition') return 0;
        return null;
      });
      final cache = AudioCache.instance;
      AudioCache.instance = _Cache();
      final audio = GameAudio();
      addTearDown(() {
        AudioCache.instance = cache;
        WidgetsBinding.instance.removeObserver(audio);
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(global, null);
        messenger.setMockMethodCallHandler(events, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      SharedPreferences.setMockInitialValues({
        'audio.music': false,
        'audio.effects': false,
      });
      await audio.initialize(await SharedPreferences.getInstance());
      audio.unlock();
      Future<void> drain() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      var before = calls.length;
      audio.playCombat([GameSfx.marusLauncher]);
      await drain();
      expect(calls.length, before);
      audio.configure(effects: true, sfxGain: 0);
      before = calls.length;
      audio.playCombat([GameSfx.marusLauncher]);
      await drain();
      expect(calls.where((c) => c.method == 'create'), isEmpty);
      audio.configure(sfxGain: .4);
      audio.playCombat([GameSfx.marusLauncher, GameSfx.marusHarvest]);
      await drain();
      expect(calls.where((c) => c.method == 'resume').length, 2);
      final voiceIds = calls
          .where((c) => c.method == 'create')
          .map((c) => (c.arguments as Map)['playerId'])
          .toSet();
      expect(voiceIds.length, 2);
      for (final call in calls.where((c) => c.method == 'setVolume')) {
        expect(
          (call.arguments as Map)['volume'],
          inInclusiveRange(0, .4 * .5 * 1.08),
        );
      }
      audio.pauseGame(true);
      await drain();
      before = calls.where((c) => c.method == 'resume').length;
      audio.playCombat(CombatSfxLimiter.priorities.keys);
      await drain();
      expect(calls.where((c) => c.method == 'resume').length, before);
      expect(
        calls.where((c) => c.method == 'stop').length,
        greaterThanOrEqualTo(2),
      );
      audio.pauseGame(false);
      audio.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await drain();
      audio.playCombat([GameSfx.marusLauncher]);
      await drain();
      expect(calls.where((c) => c.method == 'resume').length, before);
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      audio.configure(effects: false);
      await drain();
      audio.playCombat([GameSfx.marusLauncher]);
      await drain();
      expect(calls.where((c) => c.method == 'resume').length, before);
      audio.configure(effects: true);
      audio.play(GameSfx.marusCardVictory);
      await drain();
      final cardId = calls
          .lastWhere((c) => c.method == 'create')
          .arguments['playerId'];
      expect(voiceIds.contains(cardId), false);
      final start = calls.length;
      audio.stopCombat();
      await drain();
      expect(
        calls
            .skip(start)
            .where((c) => (c.arguments as Map)['playerId'] == cardId),
        isEmpty,
      );
      audio.stopEffect(GameSfx.marusCardVictory);
      await drain();
      // The supplied Patio OST loops, resumes after pause and keeps its source
      // when the music slider changes. SFX and card players remain separate.
      audio.enter('marus-zombies-patio');
      audio.configure(music: true);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      final source = calls.lastWhere((c) => c.method == 'setSourceUrl');
      expect(source.arguments['url'], contains('zombies-on-your-lawn.mp3'));
      final musicId = source.arguments['playerId'];
      expect(
        calls
            .where(
              (c) =>
                  c.method == 'setReleaseMode' &&
                  c.arguments['playerId'] == musicId,
            )
            .last
            .arguments['releaseMode'],
        'ReleaseMode.loop',
      );
      final sourceCount = calls.where((c) => c.method == 'setSourceUrl').length;
      audio.configure(musicGain: .15);
      await drain();
      expect(
        calls.where((c) => c.method == 'setSourceUrl').length,
        sourceCount,
      );
      audio.pauseGame(true);
      await drain();
      expect(
        calls.any(
          (c) => c.method == 'pause' && c.arguments['playerId'] == musicId,
        ),
        true,
      );
      audio.pauseGame(false);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      expect(
        calls.where((c) => c.method == 'setSourceUrl').length,
        sourceCount,
      );
      audio.configure(music: false);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    },
  );
}
