import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/wordle_entry.dart';
import 'package:nuestro_rincon/wordle.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_care.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/audio_settings_panel.dart';
import 'package:nuestro_rincon/brand_title.dart';
import 'package:nuestro_rincon/game_result.dart';
import 'package:nuestro_rincon/trade_merge.dart';
import 'package:nuestro_rincon/sweet_screen.dart';
import 'package:nuestro_rincon/match3.dart';

void main() {
  test('Hint cells survive deletion and all future guesses', () {
    final entry = WordleEntry()
      ..reveal(1, 'A')
      ..reveal(4, 'S');
    for (final c in 'CTO'.split('')) {
      entry.type(c);
    }
    expect(entry.word, 'CATOS');
    entry.delete();
    expect(entry.cells, ['C', 'A', 'T', '', 'S']);
    entry.delete();
    entry.delete();
    entry.delete();
    expect(entry.cells, ['', 'A', '', '', 'S']);
    entry.type('G');
    entry.type('T');
    entry.type('O');
    expect(entry.word, 'GATOS');
    expect(entry.complete, isTrue);
    entry.clear();
    expect(entry.cells, ['', 'A', '', '', 'S']);
  });
  test(
    'Meow shuffle plays seven recordings without consecutive repetitions',
    () {
      final rotation = MeowRotation(random: Random(14));
      String? previous;
      for (var round = 0; round < 20; round++) {
        final bag = <String>{};
        for (var i = 0; i < 7; i++) {
          final file = rotation.next();
          expect(file, isNot(previous));
          bag.add(file);
          previous = file;
        }
        expect(bag, MeowRotation.assets.toSet());
      }
    },
  );
  test(
    'Expanded offline dictionary includes plurals, conjugations and Ñ',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final words = (await rootBundle.loadString(
        'assets/wordle_expanded.txt',
      )).split('\n').map((w) => w.trim()).toSet();
      expect(words.length, greaterThan(8500));
      expect(
        words,
        containsAll([
          'NIÑAS',
          'CASAS',
          'GATAS',
          'COMES',
          'BEBES',
          'BAÑAS',
          'LEYES',
          'REZAR',
        ]),
      );
      expect(normalizeWordle('sueño'), 'SUEÑO');
      expect(normalizeWordle('árbol'), 'ARBOL');
    },
  );
  test(
    'Clothes charge once, share ownership and persist with exact price tiers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance());
      expect(catWardrobe.map((i) => i.price).toSet(), {
        100,
        150,
        250,
        500,
        1000,
      });
      final garment = clothingById('shirt_dragon')!;
      expect(await store.buyCatClothing(garment), isFalse);
      store.coins = 1200;
      expect(await store.buyCatClothing(garment), isTrue);
      expect(store.coins, 200);
      expect(await store.buyCatClothing(garment), isTrue);
      expect(store.coins, 200);
      await store.catCare.equip(CatKind.maru, garment);
      await store.catCare.equip(CatKind.lady, garment);
      final restored = GameStore(prefs);
      expect(restored.coins, 200);
      expect(restored.catCare.outfit(CatKind.maru).body, 'shirt_dragon');
      expect(restored.catCare.outfit(CatKind.lady).body, 'shirt_dragon');
      expect(restored.cloud.snapshot(), contains('ownedClothes'));
    },
  );
  test('Legacy worn garments stay owned after the paid wardrobe migration', () {
    final care = CatCare();
    final legacy = care.toJson()..remove('ownedClothes');
    (legacy['lady'] as Map)['outfit'] = {
      'head': 'crown',
      'body': 'shirt_space',
    };
    care.restore(legacy);
    expect(care.outfit(CatKind.lady).head, 'crown');
    expect(care.ownsClothing(clothingById('crown')!), isTrue);
    expect(care.ownsClothing(clothingById('shirt_space')!), isTrue);
  });
  test(
    'Server trade receipts merge once and preserve offline games and coins',
    () {
      String payload(Map<String, dynamic> core) => jsonEncode({
        'rincon.v1': jsonEncode(core),
        'wordle.v1': 'local-round',
      });
      final local = payload({
        'coins': 800,
        'cardVariants': {'1:rare:silver': 2, '3:common:normal': 1},
        'tradeReceipts': {},
      });
      final remote = payload({
        'coins': 300,
        'tradeReceipts': {
          'trade': {
            'outgoing': '1:rare:silver',
            'incoming': '2:epic:gold',
            'opener': 1,
            'collection': 'vol2',
          },
        },
      });
      final merged = mergeTradeReceipts(local, remote);
      final core = jsonDecode(jsonDecode(merged)['rincon.v1']);
      expect(core['coins'], 800);
      expect(core['cardVariants'], {
        '1:rare:silver': 1,
        '3:common:normal': 1,
        '2:epic:gold': 1,
      });
      expect(core['cardOpeners']['2'], 1);
      expect(core['rarities'], {'1': 4, '3': 0, '2': 1});
      expect(mergeTradeReceipts(merged, remote), merged);
      expect(jsonDecode(merged)['wordle.v1'], 'local-round');
    },
  );
  testWidgets(
    'Title cycles through Minecraft-style Monocraft and restores the choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: BrandTitle(prefs: prefs)),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('brand-font-switch')));
        await tester.pump();
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<Text>(find.text('Anivermaru')).style!.fontFamily,
        'Monocraft',
      );
      expect(prefs.getInt('appearance.logoFont'), 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: BrandTitle(prefs: prefs)),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Anivermaru')).style!.fontFamily,
        'Monocraft',
      );
    },
  );
  testWidgets('Sound menu uses paws and fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = GameAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AudioSettingsPanel(audio: audio)),
      ),
    );
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.length, 2);
    final beforeMusic = audio.musicVolume;
    sliders.first.onChanged!(.35);
    await tester.pump();
    expect(audio.effectsVolume, .35);
    expect(audio.musicVolume, beforeMusic);
    expect(tester.takeException(), isNull);
    final sliderTheme = tester.widgetList<SliderTheme>(
      find.byType(SliderTheme),
    );
    expect(
      sliderTheme.every((t) => t.data.thumbShape is PawSliderThumb),
      isTrue,
    );
  });
  for (final game in ResultTheme.values) {
    testWidgets('Result panel for ${game.name} fits on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameResultCard(
                game: game,
                title: '¡Otra ronda!',
                detail: 'Maru y Lady te acompañan',
                stat: '100 puntos',
                caption: 'Tus monedas están guardadas',
                again: 'Otra partida',
                onAgain: () {},
                onHome: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Paid hint costs 50, travels to a cell and remains fixed after reload',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'wordle.v1': jsonEncode({
          'answer': 'GATOS',
          'guesses': [],
          'wins': 0,
          'roundId': 'paid',
        }),
      });
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance());
      store.coins = 150;
      await store.save();
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('buy-wordle-hint')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.coins, 100);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      final hints = List<int>.from(
        jsonDecode(prefs.getString('wordle.v1')!)['hints'],
      );
      expect(hints.length, 1);
      expect(prefs.getInt('wordle.hintsUsed'), 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        if (!hints.contains(i)) {
          await tester.tap(find.widgetWithText(InkWell, 'GATOS'[i]));
          await tester.pump();
        }
      }
      await tester.tap(find.widgetWithText(InkWell, 'ENVIAR'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(store.coins, 200);
      expect(find.text('¡Palabra encontrada!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final won in [true, false]) {
    testWidgets(
      'Candy ${won ? 'victory' : 'defeat'} opens a panel and preserves powers',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game =
            SweetGame(
                seed: 1234,
                level: 3,
                hammers: 0,
                switches: 1,
                extraMoves: 0,
              )
              ..won = won
              ..lost = !won;
        if (won) {
          for (final cell in game.cells) {
            cell.jelly = 0;
          }
        }
        SharedPreferences.setMockInitialValues({
          'sweet.v1': jsonEncode(game.toJson()),
        });
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          MaterialApp(home: SweetScreen(store: GameStore(prefs))),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.text(won ? '¡Dulce victoria!' : '¡Una combinación más!'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(GameResultCard),
            matching: find.text(won ? 'Siguiente nivel' : 'Reintentar'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final next = SweetGame.fromJson(
          jsonDecode(prefs.getString('sweet.v1')!),
        );
        expect(next.level, won ? 4 : 3);
        expect(next.hammers, won ? 1 : 0);
        expect(next.switches, won ? 2 : 1);
        expect(next.extraMoves, won ? 1 : 0);
        expect(next.won, isFalse);
        expect(next.lost, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Wordlady losing panel reveals the answer and opens another round',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'wordle.v1': jsonEncode({
          'answer': 'GATOS',
          'guesses': ['SALTO', 'PLAYA', 'QUESO', 'LIMON', 'LIBRO', 'NUBES'],
          'wins': 0,
          'roundId': 'lost',
        }),
      });
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance());
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('¡Otra palabra, michi!'), findsOneWidget);
      expect(store.coins, 30);
      await tester.tap(
        find.descendant(
          of: find.byType(GameResultCard),
          matching: find.text('Otra palabra'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(jsonDecode(prefs.getString('wordle.v1')!)['guesses'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
