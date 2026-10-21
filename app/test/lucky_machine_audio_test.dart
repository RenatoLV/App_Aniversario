import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_machine_audio.dart';

void main() {
  test('one start, five genuine landings, one positive-reward cue', () {
    final sound = LuckyMachineAudio();
    expect(sound.begin(hasReward: true, reduced: false), [GameSfx.casinoSpin]);
    expect(sound.advance(0), isEmpty);
    expect(sound.advance(1.99), isEmpty);
    for (var i = 0; i < 5; i++) {
      final time = 2 + i * .22;
      expect(sound.advance(time), [GameSfx.casinoStop]);
      expect(sound.advance(time + .001), isEmpty);
    }
    expect(sound.advance(3.35), [GameSfx.casinoPayout]);
    expect(sound.advance(3.36), isEmpty);
    expect(sound.advance(6.2), isEmpty);
    expect(sound.running, false);
  });
  test('no victory sound for a round without net profit', () {
    final sound = LuckyMachineAudio()..begin(hasReward: false, reduced: false);
    expect(sound.advance(3.35), isEmpty);
    expect(sound.paid, true);
    expect(sound.resumeAt(3.5), null);
  });
  test(
    'resume seeks the existing phase rather than replaying its beginning',
    () {
      final sound = LuckyMachineAudio()..begin(hasReward: true, reduced: false);
      expect(sound.resumeAt(1.2), (
        GameSfx.casinoSpin,
        const Duration(milliseconds: 1200),
      ));
      expect(sound.resumeAt(3.1), null);
      sound.advance(3.35);
      expect(sound.resumeAt(3.85), (
        GameSfx.casinoPayout,
        const Duration(milliseconds: 500),
      ));
      expect(sound.advance(3.85), isEmpty);
      expect(sound.resumeAt(5.3), null);
    },
  );
  test('skip, exit and idle cannot emit deferred rewards', () {
    final sound = LuckyMachineAudio();
    expect(sound.advance(4), isEmpty);
    sound.begin(hasReward: true, reduced: false);
    sound.cancel();
    expect(sound.advance(4), isEmpty);
    expect(sound.resumeAt(1), null);
    expect(sound.begin(hasReward: false, reduced: false), [GameSfx.casinoSpin]);
    expect(sound.landed, 0);
    expect(sound.paid, false);
  });
  test('reduced motion has one short cue and no spinning timeline', () {
    final sound = LuckyMachineAudio();
    expect(sound.begin(hasReward: true, reduced: true), [GameSfx.casinoPayout]);
    expect(sound.advance(3.35), isEmpty);
    expect(sound.resumeAt(1), null);
    expect(sound.begin(hasReward: false, reduced: true), [GameSfx.casinoStop]);
  });
  test(
    'frame jumps collapse landings, never queue old sounds after completion',
    () {
      final sound = LuckyMachineAudio()..begin(hasReward: true, reduced: false);
      expect(sound.advance(3), [GameSfx.casinoStop]);
      expect(sound.landed, 5);
      expect(sound.advance(3), isEmpty);
      expect(sound.advance(6.2), isEmpty);
      expect(sound.advance(double.nan), isEmpty);
    },
  );
  test(
    'bundled foley assets have valid PCM headers and redistributable credits',
    () {
      final manifest =
          jsonDecode(
                File('assets/audio/casino_sfx_sources.json').readAsStringSync(),
              )
              as Map;
      for (final source in manifest['sources'] as List) {
        expect(source['license'], 'CC0-1.0');
        expect(source['page'], startsWith('https://freesound.org/people/'));
        expect(source['sha256'], hasLength(64));
      }
      for (final effect in LuckyMachineAudio.effects) {
        final bytes = File('assets/audio/${effect.file}').readAsBytesSync();
        final header = ByteData.sublistView(bytes);
        expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
        expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
        expect(header.getUint16(22, Endian.little), 1);
        expect(header.getUint32(24, Endian.little), 44100);
        expect(header.getUint16(34, Endian.little), 16);
        final row = (manifest['files'] as List).singleWhere(
          (r) => r['file'] == effect.file,
        );
        expect(
          (bytes.length - 44) / 88200,
          closeTo(row['seconds'] as num, 1e-6),
        );
        expect(row['peak'], lessThan(.8));
        expect(row['rms'], greaterThan(.05));
      }
    },
  );
}
