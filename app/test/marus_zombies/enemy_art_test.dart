import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_character_art.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';

const _kinds = [MzEnemy.bucket, MzEnemy.mummy, MzEnemy.pianist, MzEnemy.mecha];

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('RENDER_MZ')) return;
    await (FontLoader('Nunito')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Nunito.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  testWidgets('four invaders render from real movement, attacks and recovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = MzSimulation(const MzLevel(8));
    final art = MzVisualFeedback();
    final enemies = [
      for (var i = 0; i < 4; i++) MzInvader(200 + i, _kinds[i], i, x: 2.07),
    ];
    sim.invaders.addAll(enemies);
    art.observe(sim);
    Future<void> frame(String pose) async {
      final before = jsonEncode(sim.toJson());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('enemy-review'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(
              painter: _EnemyReview(enemies, art, sim.time, pose),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(jsonEncode(sim.toJson()), before);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('RENDER_MZ')) {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('enemy-review')),
              )
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final phase = const String.fromEnvironment(
            'ART_PHASE',
            defaultValue: 'enemy-after',
          );
          File('build/previews/mz-$phase-$pose.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }

    await frame('idle');
    for (var i = 0; i < 36; i++) {
      sim.advance(1 / 60);
      art.observe(sim);
      if (const bool.fromEnvironment('CAPTURE_MOTION') && i % 3 == 2) {
        await frame('walk-${(i ~/ 3).toString().padLeft(2, '0')}');
      }
    }
    await frame('stride');
    for (var i = 0; i < 4; i++) {
      sim.defenders.add(MzDefender(300 + i, MzCat.barrier, i, 1));
    }
    for (
      var i = 0;
      i < 90 && enemies.any((e) => art.attack(e.id, sim.time) == 0);
      i++
    ) {
      sim.advance(1 / 60);
      art.observe(sim);
    }
    expect(enemies.any((e) => art.attack(e.id, sim.time) > 0), true);
    await frame('strike');
    for (var i = 0; i < 30; i++) {
      sim.advance(1 / 60);
      art.observe(sim);
    }
    await frame('recovery');
    final pianist = enemies[2];
    for (
      var i = 0;
      i < 800 && art.performance(pianist.id, sim.time) == 0;
      i++
    ) {
      sim.advance(1 / 60);
      art.observe(sim);
    }
    expect(art.performance(pianist.id, sim.time), greaterThan(0));
    await frame('music');
    if (const bool.fromEnvironment('CAPTURE_MOTION')) {
      for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 3; j++) {
          sim.advance(1 / 60);
          art.observe(sim);
        }
        await frame('music-${i.toString().padLeft(2, '0')}');
      }
    }
    // Armorless preview is a fixture state, not a claimed combat event.
    enemies.first.armor = 0;
    await frame('armorless');
    await tester.pumpWidget(const SizedBox());
  });
}

class _EnemyReview extends CustomPainter {
  const _EnemyReview(this.enemies, this.art, this.time, this.pose);
  final List<MzInvader> enemies;
  final MzVisualFeedback art;
  final double time;
  final String pose;
  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xfffff3d5));
    for (var i = 0; i < enemies.length; i++) {
      final e = enemies[i], x = 120 + i * 240.0;
      mzText(c, e.kind.label, Offset(x, 35), 18, const Color(0xff30382f));
      for (final entry in [(160.0, 190.0), (64.0, 315.0), (32.0, 410.0)]) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, entry.$2 + entry.$1 * .18),
            width: entry.$1,
            height: entry.$1 * .25,
          ),
          Paint()..color = const Color(0xffa6c578),
        );
        mzPaintCharacter(
          c,
          Offset(x, entry.$2),
          entry.$1,
          enemy: e.kind,
          phase: time + e.id * .31,
          armor: e.armor > 0,
          walking: art.walking(e.id),
          attack: art.attack(e.id, time),
          hurt: art.hurt(e.id, time),
          performance: art.performance(e.id, time),
        );
      }
      mzText(
        c,
        '160 / 64 / 32 px',
        Offset(x, 475),
        14,
        const Color(0xff30382f),
      );
      // Static silhouette comparison; the same pose and equipment as portrait.
      c.saveLayer(
        Rect.fromLTWH(x - 90, 495, 180, 155),
        Paint()
          ..colorFilter = const ColorFilter.mode(
            Color(0xff30382f),
            BlendMode.srcIn,
          ),
      );
      mzPaintCharacter(
        c,
        Offset(x, 610),
        112,
        enemy: e.kind,
        phase: 0,
        armor: e.armor > 0,
        walking: false,
      );
      c.restore();
    }
    mzText(
      c,
      '$pose · t=${time.toStringAsFixed(2)}',
      const Offset(480, 640),
      12,
      const Color(0xff30382f),
    );
  }

  @override
  bool shouldRepaint(_EnemyReview old) => true;
}
