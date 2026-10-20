import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_catalog.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_local_repository.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_screen.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_ticket_widget.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_models.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'lucky_repository_test.dart' show FixedStops;

const scratchCapture = String.fromEnvironment('SCRATCH_CAPTURE');
const boundary = ValueKey('scratch-capture');

class InterruptedScratch extends ScratchLocalRepository {
  InterruptedScratch(super.storage, {super.random});
  bool fail = true;
  @override
  Future<ScratchReceipt> execute(String id) async {
    if (fail) throw StateError('Simulated lost confirmation');
    return super.execute(id);
  }
}

Future<void> captureScratch(WidgetTester t, String name) async {
  if (scratchCapture.isEmpty) return;
  await t.runAsync(() async {
    final image = await t
        .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(scratchCapture).createSync(recursive: true);
    File(
      '$scratchCapture/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> ready(WidgetTester t) async {
  for (var i = 0; i < 120; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 20));
    if (find.byKey(const ValueKey('scratch-ticket')).evaluate().isNotEmpty) {
      await t.pumpAndSettle();
      return;
    }
  }
  throw TestFailure('Ticket artwork failed to load');
}

Widget app(ScratchLocalRepository repo, double scale, {bool reduced = false}) =>
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: ScratchScreen(repository: repo),
      ),
    );
void main() {
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
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'Patita real foil, sealed receipt and accessible layouts ${size.width} $scale',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final db = (await t.runAsync(
            () => databaseFactoryMemory.openDatabase(
              'scratch-${size.width}-$scale',
            ),
          ))!;
          final rng = FixedStops([0, 0, 0, 1, 1, 2, 3, 4, 5]);
          final repo = ScratchLocalRepository(LuckyDatabase(db), random: rng);
          await t.pumpWidget(app(repo, scale));
          await ready(t);
          expect(rng.calls, 0);
          expect(find.byType(ScratchTicketWidget), findsOneWidget);
          await captureScratch(
            t,
            'catalog-${size.width.toInt()}-${(scale * 100).round()}',
          );
          await t.tap(find.byKey(const ValueKey('scratch-primary')));
          await ready(t);
          expect(rng.calls, 9);
          final sealed = (await t.runAsync(repo.recover))!;
          expect(sealed.revealed, false);
          expect(sealed.gross, 3);
          expect(await t.runAsync(repo.balance), 493);
          final ticket = t.getRect(
                find.byKey(const ValueKey('scratch-ticket')),
              ),
              foil = t.getRect(find.byKey(const ValueKey('scratch-surface')));
          expect(ticket.contains(foil.topLeft), true);
          expect(ticket.contains(foil.bottomRight), true);
          expect(ticket.width / ticket.height, closeTo(2 / 3, 1e-8));
          expect(foil.width, greaterThanOrEqualTo(160));
          for (final key in [
            'scratch-primary',
            'scratch-back',
            'scratch-history',
            'scratch-help',
          ]) {
            final rect = t.getRect(find.byKey(ValueKey(key)));
            expect(rect.shortestSide, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width + .1));
            expect(rect.bottom, lessThanOrEqualTo(size.height + .1));
          }
          final cats = t
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((p) => p.painter);
          expect(cats.whereType<MaruPainter>().length, 1);
          expect(cats.whereType<LadyPainter>().length, 1);
          // ignore: avoid_print
          print(
            'SCRATCH_GEOMETRY ${jsonEncode({
              'width': size.width,
              'height': size.height,
              'text': scale,
              'ticket': [ticket.left, ticket.top, ticket.width, ticket.height],
              'foil': [foil.left, foil.top, foil.width, foil.height],
            })}',
          );
          await captureScratch(
            t,
            'covered-${size.width.toInt()}-${(scale * 100).round()}',
          );
          final gesture = await t.startGesture(
            foil.topLeft + Offset(foil.width * .2, foil.height * .25),
          );
          await gesture.moveTo(
            foil.topLeft + Offset(foil.width * .8, foil.height * .25),
          );
          await gesture.up();
          await t.pumpAndSettle();
          final partial = (await t.runAsync(repo.recover))!;
          expect(partial.mask.coverage, greaterThan(0));
          expect(partial.mask.coverage, lessThan(.6));
          await captureScratch(
            t,
            'partial-${size.width.toInt()}-${(scale * 100).round()}',
          );
          await t.tap(find.byKey(const ValueKey('scratch-primary')));
          await t.pumpAndSettle();
          expect((await t.runAsync(repo.recover))!.revealed, true);
          expect(rng.calls, 9);
          expect(await t.runAsync(repo.balance), 493);
          await captureScratch(
            t,
            'revealed-${size.width.toInt()}-${(scale * 100).round()}',
          );
          expect(
            find.text(
              size.width > size.height ? 'Ver resultado' : 'Premio 3 · Neto -7',
            ),
            findsOneWidget,
          );
          expect(t.takeException(), null);
          await t.pumpWidget(const SizedBox());
          await t.runAsync(db.close);
        },
      );
    }
  }
  testWidgets(
    'five themes use supplied layers and original cats; no result on previews',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('scratch-five'),
      ))!;
      final rng = FixedStops([0]);
      final repo = ScratchLocalRepository(LuckyDatabase(db), random: rng);
      await t.pumpWidget(app(repo, 1));
      await ready(t);
      for (final theme in ScratchTheme.all) {
        await t.ensureVisible(
          find.byKey(ValueKey('scratch-theme-${theme.id}')),
        );
        await t.tap(find.byKey(ValueKey('scratch-theme-${theme.id}')));
        await ready(t);
        expect(
          t
              .widget<ScratchTicketWidget>(find.byType(ScratchTicketWidget))
              .theme
              .id,
          theme.id,
        );
        await captureScratch(t, 'theme-${theme.id}');
      }
      expect(rng.calls, 0);
      expect(await t.runAsync(repo.history), isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
  testWidgets(
    'multi-touch, bounds, reduced motion and partial restoration never reroll',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('scratch-fingers'),
      ))!;
      final rng = FixedStops([0]);
      final repo = ScratchLocalRepository(LuckyDatabase(db), random: rng);
      await t.pumpWidget(app(repo, 2, reduced: true));
      await ready(t);
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await ready(t);
      final box = t.getRect(find.byKey(const ValueKey('scratch-surface')));
      final one = await t.startGesture(
        box.topLeft + Offset(box.width * .2, box.height * .25),
        pointer: 1,
      );
      final two = await t.startGesture(
        box.topLeft + Offset(box.width * .2, box.height * .75),
        pointer: 2,
      );
      await one.moveTo(box.topLeft + Offset(box.width * .6, box.height * .25));
      await two.moveTo(box.topLeft + Offset(box.width * .6, box.height * .75));
      await one.up();
      await two.up();
      await t.pumpAndSettle();
      final partial = (await t.runAsync(repo.recover))!;
      expect(partial.mask.coverage, greaterThan(0));
      expect(partial.revealed, false);
      final encoded = partial.mask.encode();
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(repo, 2, reduced: true));
      await ready(t);
      expect((await t.runAsync(repo.recover))!.mask.encode(), encoded);
      expect(rng.calls, 9);
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await t.pumpAndSettle();
      final handle = t.ensureSemantics();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      expect((await t.runAsync(repo.history))!.length, 1);
      expect(await t.runAsync(repo.balance), 493);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
  testWidgets(
    'failed confirmation reveals nothing; retry recovers the sealed outcome',
    (t) async {
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('scratch-error-ui'),
      ))!;
      final rng = FixedStops([0]);
      final repo = InterruptedScratch(LuckyDatabase(db), random: rng);
      await t.pumpWidget(app(repo, 1));
      await ready(t);
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await t.pumpAndSettle();
      expect(find.text('REINTENTAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('scratch-surface')), findsNothing);
      expect(await t.runAsync(repo.balance), 500);
      expect(await t.runAsync(repo.history), isEmpty);
      expect(rng.calls, 9);
      repo.fail = false;
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await ready(t);
      expect(find.byKey(const ValueKey('scratch-surface')), findsOneWidget);
      expect(await t.runAsync(repo.balance), 493);
      expect(rng.calls, 9);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
  testWidgets(
    'cabinet navigation shares chips, preserves ticket and returns without payment',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('scratch-cabinet-ui'),
      ))!;
      final storage = LuckyDatabase(db);
      final slot = LocalLuckyRoundRepository(storage, random: FixedStops([0]));
      final scratch = ScratchLocalRepository(storage);
      await t.pumpWidget(
        MaterialApp(home: LuckyPalaceScreen(localRepository: slot)),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('lucky-scratch')));
      await ready(t);
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await ready(t);
      final sealed = (await t.runAsync(scratch.recover))!;
      final box = t.getRect(find.byKey(const ValueKey('scratch-surface')));
      await t.dragFrom(box.center, const Offset(50, 0));
      await t.pumpAndSettle();
      final partial = (await t.runAsync(scratch.recover))!;
      expect(partial.mask.coverage, greaterThan(0));
      // First back shows catalog; second returns to the cabinet.
      await t.tap(find.byKey(const ValueKey('scratch-back')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('scratch-back')));
      await t.pumpAndSettle();
      expect(find.byType(ScratchScreen), findsNothing);
      expect((await t.runAsync(slot.refresh))!.balance, sealed.balance);
      await t.tap(find.byKey(const ValueKey('lucky-scratch')));
      await ready(t);
      expect((await t.runAsync(scratch.recover))!.data, sealed.data);
      expect(
        (await t.runAsync(scratch.recover))!.mask.encode(),
        partial.mask.encode(),
      );
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await t.pumpAndSettle();
      expect((await t.runAsync(slot.refresh))!.balance, sealed.balance);
      expect(await t.runAsync(slot.history), isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
  testWidgets(
    'real 60 percent coverage auto-reveals; repeated gestures do not double pay',
    (t) async {
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('scratch-auto'),
      ))!;
      final rng = FixedStops([0]);
      final repo = ScratchLocalRepository(LuckyDatabase(db), random: rng);
      await t.pumpWidget(app(repo, 1));
      await ready(t);
      await t.tap(find.byKey(const ValueKey('scratch-primary')));
      await ready(t);
      final box = t.getRect(find.byKey(const ValueKey('scratch-surface')));
      for (var y = 12.0; y < box.height; y += 22) {
        final g = await t.startGesture(Offset(box.left + 1, box.top + y));
        await g.moveTo(Offset(box.right - 1, box.top + y));
        await g.up();
        await t.pumpAndSettle();
        if ((await t.runAsync(repo.recover))!.revealed) break;
      }
      expect((await t.runAsync(repo.recover))!.revealed, true);
      expect(await t.runAsync(repo.balance), 493);
      expect(rng.calls, 9);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    },
  );
}
