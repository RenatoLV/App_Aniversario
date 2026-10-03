// Isolated visual QA entrypoint. Never used by the production main.dart.
// Serve on a separate origin to avoid modifying the player's local progress.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/bomber/bomber_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final store = GameStore(await SharedPreferences.getInstance());
  for (final c in celestialCatalog) {
    store.cards[c.id] = 1;
    store.rarities[c.id] = CardRarity.celestial;
    store.cardVariants['${c.id}:celestial:normal'] = 1;
    store.cardCollections[c.id] = c.volume == 1
        ? anniversaryCollectionId
        : anniversaryCollectionV2Id;
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xff171a36),
        body: Builder(
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Prueba visual · cartas celestiales',
                  style: TextStyle(color: Colors.white),
                ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BomberScreen(store: store),
                    ),
                  ),
                  child: const Text('Probar Bomber Miau'),
                ),
                for (final c in celestialCatalog.take(4))
                  FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CardRevealDialog(
                        cardId: c.id,
                        copies: 1,
                        total: 1,
                        opener: CatKind.maru,
                        rarity: CardRarity.celestial,
                        collectionId: c.volume == 1
                            ? anniversaryCollectionId
                            : anniversaryCollectionV2Id,
                      ),
                    ),
                    child: Text('Revelar ${c.name}'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RinconApp(store: store),
                    ),
                  ),
                  child: const Text('Abrir colección de prueba'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
