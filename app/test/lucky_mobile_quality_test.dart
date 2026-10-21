import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/remote_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_console_controls.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_cabinet_art.dart';
import 'lucky_repository_test.dart' show FixedStops, SandboxFixture;
import 'lucky_hybrid_screen_test.dart' show snapshot, boundary, confirmedCells;

class FaultRepository implements LuckyRoundRepository {
  FaultRepository(this.base);
  final LocalLuckyRoundRepository base;
  @override
  LuckyOrigin get origin => base.origin;
  @override
  Future<LuckyWalletSnapshot> refresh() => base.refresh();
  @override
  Future<LuckyRoundIntent> prepare() => base.prepare();
  @override
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent i) async =>
      throw StateError('injected write failure');
  @override
  Future<LuckyRoundReceipt?> recover() => base.recover();
  @override
  Future<List<LuckyRoundReceipt>> history() => base.history();
  @override
  Future<void> acknowledge(String id, LuckyPresentation p) =>
      base.acknowledge(id, p);
}

class GatedFaultRepository extends FaultRepository {
  GatedFaultRepository(super.base);
  final gate = Completer<void>();
  @override
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent intent) async {
    await gate.future;
    throw StateError('injected write failure');
  }
}

class DelayedRepository extends FaultRepository {
  DelayedRepository(super.base);
  final confirmed = Completer<void>();
  @override
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent intent) async {
    final receipt = await base.execute(intent);
    await confirmed.future;
    return receipt;
  }
}

LuckyCabinetPainter foreground(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<LuckyCabinetPainter>()
    .firstWhere((p) => p.foreground);
void main() {
  testWidgets(
    'confirmation in background waits for discovery and shows committed bonus',
    (tester) async {
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('background-result'),
      ))!;
      final base = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([14, 6, 3, 9, 10]),
      );
      final delayed = DelayedRepository(base);
      await tester.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            localRepository: delayed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      delayed.confirmed.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(foreground(tester).frame.started, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(foreground(tester).frame.started, false);
      expect(find.byKey(const ValueKey('lucky-free-count')), findsOneWidget);
      if (find
          .byKey(const ValueKey('lucky-present-pending'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const ValueKey('lucky-details')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('lucky-present-pending')),
      );
      await tester.tap(find.byKey(const ValueKey('lucky-present-pending')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(base.history))!.length, 1);
      expect((await tester.runAsync(base.refresh))!.balance, 495);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
  setUpAll(() async {
    for (final family in ['Fredoka', 'Nunito']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    for (final textScale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'HUD distinguishes previous result from next cost ${size.width} $textScale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = (await tester.runAsync(
            () => databaseFactoryMemory.openDatabase(
              'mobile-${size.width}-$textScale',
            ),
          ))!;
          final repo = LocalLuckyRoundRepository(
            LuckyDatabase(db),
            random: FixedStops([14, 6, 3, 9, 10, 0, 0, 0, 0, 0]),
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: LuckyPalaceScreen(
                  enableDeveloperTools: true,
                  localRepository: repo,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('lucky-wallet')), findsOneWidget);
          expect(find.byKey(const ValueKey('lucky-mode-online')), findsNothing);
          expect(
            tester.getSize(find.byKey(const ValueKey('lucky-spin'))).height,
            greaterThanOrEqualTo(68),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('lucky-lever')))
                .shortestSide,
            greaterThanOrEqualTo(48),
          );
          await tester.tap(find.byKey(const ValueKey('lucky-spin')));
          await tester.pumpAndSettle();
          expect(
            find.text(size.width < size.height ? '495' : 'Fichas: 495'),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('lucky-net')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('lucky-free-count')),
            findsOneWidget,
          );
          final regions = <String, Rect>{};
          for (final key in [
            'appbar-region',
            'hud-region',
            'cabinet-region',
            'art-bounds',
            'reels-bounds',
            'spin',
            'toolbar-region',
            'symbols',
          ]) {
            final f = find.byKey(ValueKey('lucky-$key'));
            expect(f, findsOneWidget);
            final rect = tester.getRect(f);
            regions[key] = rect;
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width + .01));
            expect(rect.bottom, lessThanOrEqualTo(size.height + .01));
          }
          for (final root in [
            'lucky-appbar-region',
            'lucky-hud-region',
            'lucky-spin',
            'lucky-toolbar-region',
          ]) {
            for (final rich
                in find
                    .descendant(
                      of: find.byKey(ValueKey(root)),
                      matching: find.byType(RichText),
                    )
                    .evaluate()) {
              final paragraph = rich.renderObject! as RenderParagraph;
              expect(paragraph.didExceedMaxLines, false);
              expect(
                paragraph.size.height + 1,
                greaterThanOrEqualTo(
                  paragraph.getMinIntrinsicHeight(paragraph.size.width),
                ),
                reason: 'Text clipped inside $root at $size / $textScale',
              );
            }
          }
          expect(regions['spin']!.overlaps(regions['reels-bounds']!), false);
          expect(
            regions['toolbar-region']!.overlaps(regions['art-bounds']!),
            false,
          );
          if (size.width < size.height) {
            expect(
              regions['art-bounds']!.width / size.width,
              greaterThanOrEqualTo(.8),
            );
            expect(
              regions['cabinet-region']!.height / size.height,
              greaterThanOrEqualTo(.55),
            );
            expect(regions['hud-region']!.height, lessThanOrEqualTo(105));
          }
          // ignore: avoid_print
          print(
            'RESPONSIVE_GEOMETRY ${jsonEncode({
              'width': size.width,
              'height': size.height,
              'text': textScale,
              'regions': regions.map((k, r) => MapEntry(k, [r.left, r.top, r.width, r.height])),
            })}',
          );
          await tester.tap(find.byKey(const ValueKey('lucky-details')));
          await tester.pumpAndSettle();
          expect(find.text('Premio bruto: 20'), findsOneWidget);
          expect(find.text('Coste cobrado: 25'), findsOneWidget);
          expect(find.text('Neto: -5'), findsOneWidget);
          expect(find.text('Siguiente giro: gratis. Coste 0.'), findsOneWidget);
          expect(find.text('Giros gratis concedidos: 12'), findsOneWidget);
          expect(find.textContaining('Recibo:'), findsOneWidget);
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();
          final r = (await tester.runAsync(repo.history))!.single;
          confirmedCells(tester, r.round);
          {
            await snapshot(
              tester,
              'quality-${size.width.toInt()}-${(textScale * 100).round()}',
            );
          }
          await tester.tap(find.byKey(const ValueKey('lucky-spin')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('lucky-status')))
                .data,
            'Girando…',
          );
          expect(foreground(tester).frame.previousRound!.evaluation.total, 20);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('lucky-net')), findsOneWidget);
          expect(
            find.text(size.width < size.height ? '11' : 'Gratis: 11'),
            findsOneWidget,
          );
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(db.close);
        },
      );
    }
  }
  testWidgets(
    'HUD and static layer stay identical between frames; pause, duplicate taps and lifecycle',
    (tester) async {
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('phase-boundaries'),
      ))!;
      final rng = FixedStops([14, 6, 3, 9, 10]);
      final repo = LocalLuckyRoundRepository(LuckyDatabase(db), random: rng);
      await tester.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            localRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      final wallet = tester.widget(find.byKey(const ValueKey('lucky-wallet')));
      final background = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere(
            (w) =>
                w.painter is LuckyCabinetPainter &&
                !(w.painter as LuckyCabinetPainter).foreground,
          );
      final seconds = foreground(tester).frame.seconds;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget(find.byKey(const ValueKey('lucky-wallet'))),
        same(wallet),
      );
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .contains(background),
        true,
      );
      expect(foreground(tester).frame.seconds, greaterThan(seconds));
      await tester.tap(find.byKey(const ValueKey('lucky-pause')));
      await tester.pump();
      final paused = foreground(tester).frame.seconds;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 9));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(foreground(tester).frame.seconds, paused);
      expect(rng.calls, 5);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(repo.history))!.length, 1);
      expect(rng.calls, 5);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'failed write never animates or publishes an unconfirmed balance; recovery keeps original ID',
    (tester) async {
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('failed-quality'),
      ))!;
      final base = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            localRepository: FaultRepository(base),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se confirmó la escritura'),
        findsOneWidget,
      );
      expect(foreground(tester).frame.started, false);
      expect((await tester.runAsync(base.refresh))!.balance, 500);
      expect(await tester.runAsync(base.history), isEmpty);
      await tester.tap(find.byKey(const ValueKey('lucky-recover')));
      await tester.pumpAndSettle();
      expect(find.text('Ver pendiente'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-skip-pending')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(base.refresh))!.balance, 475);
      expect((await tester.runAsync(base.history))!.length, 1);
      await tester.tap(find.byKey(const ValueKey('lucky-details')));
      await tester.pumpAndSettle();
      expect(find.text('Neto: -25'), findsOneWidget);
      expect(find.text('Coste cobrado: 25'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'several remote pending receipts are recovered consecutively without new charges',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('pending-devices'),
      ))!;
      final server = SandboxFixture();
      await tester.runAsync(() async {
        for (var n = 0; n < 2; n++) {
          final device = await databaseFactoryMemory.openDatabase(
            'pending-device-$n',
          );
          final r = RemoteLuckyRoundRepository(
            storage: LuckyDatabase(device),
            ownerUid: 'alice',
            call: server.call,
          );
          await r.execute(await r.prepare());
          await device.close();
        }
      });
      final local = LocalLuckyRoundRepository(LuckyDatabase(db));
      final remote = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'alice',
        call: server.call,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            localRepository: local,
            connectSandbox: () async => remote,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-mode-online')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        expect(find.text('Ver pendiente'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('lucky-skip-pending')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Ver pendiente'), findsNothing);
      expect(server.charges, 2);
      expect(server.balance, 50);
      expect((await tester.runAsync(local.refresh))!.balance, 500);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'compact 200 percent: saving, error, recovery and bonus keep geometry stable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('responsive-states'),
      ))!;
      final base = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([14, 6, 3, 9, 10]),
      );
      final failing = GatedFaultRepository(base);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: LuckyPalaceScreen(
              enableDeveloperTools: true,
              localRepository: failing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester.getRect(
        find.byKey(const ValueKey('lucky-art-bounds')),
      );
      final button = tester.getRect(find.byKey(const ValueKey('lucky-spin')));
      void stable() {
        expect(
          tester.getRect(find.byKey(const ValueKey('lucky-art-bounds'))),
          region,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('lucky-spin'))),
          button,
        );
        expect(tester.takeException(), null);
      }

      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Guardando'), findsOneWidget);
      stable();
      await snapshot(tester, 'state-saving-360-200');
      failing.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Revisar aviso'), findsOneWidget);
      stable();
      await snapshot(tester, 'state-error-360-200');
      await tester.tap(find.byKey(const ValueKey('lucky-details')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No se confirmó la escritura'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('lucky-recover')));
      await tester.tap(find.byKey(const ValueKey('lucky-recover')));
      await tester.pumpAndSettle();
      stable();
      expect(find.byKey(const ValueKey('lucky-free-count')), findsOneWidget);
      expect(find.text('Ver pendiente'), findsOneWidget);
      await snapshot(tester, 'state-pending-360-200');
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('lucky-skip-pending')),
      );
      await tester.tap(find.byKey(const ValueKey('lucky-skip-pending')));
      await tester.pumpAndSettle();
      stable();
      expect((await tester.runAsync(base.history))!.length, 1);
      await tester.tap(find.byKey(const ValueKey('lucky-details')));
      await tester.pumpAndSettle();
      expect(find.text('Coste cobrado: 25'), findsOneWidget);
      await snapshot(tester, 'state-details-360-200');
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'compact accessible controls, semantics, pause, gallery and insufficient balance',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('responsive-empty'),
      ))!;
      final base = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 19; i++) {
          final r = await base.execute(await base.prepare());
          await base.acknowledge(r.id, LuckyPresentation.seen);
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: LuckyPalaceScreen(
              enableDeveloperTools: true,
              localRepository: base,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('lucky-art-bounds')),
      );
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('lucky-pause')));
      await tester.pump();
      expect(find.text('Pausa'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('lucky-art-bounds'))),
        rect,
      );
      await snapshot(tester, 'state-pause-360-200');
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('Recargar fichas'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('lucky-art-bounds'))),
        rect,
      );
      await snapshot(tester, 'state-insufficient-360-200');
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('lucky-symbols')))
            .getSemanticsData()
            .label,
        contains('Explorar símbolos'),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('lucky-symbols')))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.byKey(const ValueKey('lucky-history')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Historial ·'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-symbols')));
      await tester.pumpAndSettle();
      expect(find.text('Galería de símbolos'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.tap(find.byKey(const ValueKey('lucky-symbols')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-details')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('lucky-refill')));
      await tester.tap(find.byKey(const ValueKey('lucky-refill')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lucky-wallet')), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'large compact counters preserve exact accessible values without clipping',
    (tester) async {
      final handle = tester.ensureSemantics();
      for (final entry in {
        '142820': '142k',
        '14354981': '14M',
        '9007199254740991': '9.0P',
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 104,
                  height: 56,
                  child: LuckyResourceValue(
                    label: 'Fichas',
                    value: entry.key,
                    icon: Icons.toll_rounded,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.bySemanticsLabel('Fichas: ${entry.key}'), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(entry.value),
            matching: find.byType(RichText),
          ),
        );
        expect(
          paragraph.size.height + 1,
          greaterThanOrEqualTo(
            paragraph.getMinIntrinsicHeight(paragraph.size.width),
          ),
        );
        expect(tester.takeException(), null);
      }
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
