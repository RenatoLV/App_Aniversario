# Anivermaru 1.4

- Wordlady: two daily free hints plus extra hints for 50 coins. Lady carries the letter to its cell; it stays locked when typing, deleting and starting subsequent guesses. Reloading retains the revealed cells. No purchase is made after finishing or when all positions are known.
- Offline vocabulary: 9,021 generated five-letter forms in addition to the existing dictionaries and curated answers. `tool/expand_wordle_dictionary.py` uses the original Hunspell affixes to expand plurals and conjugations. Accents normalize; Ñ stays distinct. Answers remain common curated words.
- Game-specific result cards for Block Blaster, Candy Churu Cat, Wordlady and Ascenso. Candy displays victory/defeat and keeps unused powers when retrying. Wordlady displays both outcomes and lets the player start another word.
- Sound: Maru/Lady menu, paw-shaped slider handles, separate effect/music controls and seven alternating meow recordings. Credits are in `assets/audio/LICENSES.md`.
- Clothes: 60 garments, 15 per category, with prices of 100, 150, 250, 500 and 1,000 coins. Four starter garments and previously worn items remain owned. Purchases unlock a garment for both cats and synchronize within the existing progress snapshot. Shared painting applies sleeves, rounded hems, shading and the new designs across games and animations.
- Title: tap Anivermaru to cycle the classic, Fredoka, Nunito and Minecraft-inspired Monocraft fonts. Selection is saved locally. Font license files are under `assets/fonts/`.
- Ascenso: every scenery stage is twice its previous length (at least the requested 90% increase). Jump physics, camera positions and power spacing are unchanged. Scenery details fade smoothly across region boundaries.

## Card exchanges

Collection → Intercambiar cartas. Google users can share their collection, search the existing username directory, view another shared collection and offer an exact rarity/finish for another exact variant. Received requests can be accepted or rejected; sent requests can be cancelled. Only the recipient can accept. At most ten outgoing requests may be pending.

The HTTPS Firebase function `cardTrades`, deployed in `cumplemes/us-central1`, verifies Firebase ID tokens. Acceptance updates both private progress documents and the request status in a single Firestore transaction. Availability is checked again when accepting. Repeated acceptance is idempotent. No email, coins or other private progress are included in public collection responses. Firestore clients can read participating requests but cannot write requests or other users' inventories directly.

Trade receipts synchronize each transfer once and merge into offline local progress while keeping coins and game state. Copies, rarity summaries and card metadata are rebuilt together. Existing progress conflict/recovery behavior remains available.

Server source: `functions/`. Deployment: `firebase deploy --only functions:cardTrades,firestore:rules --project cumplemes`. Container images have a seven-day cleanup policy. GitHub tests the exchange helper and runs Flutter checks before building signed APK releases; Firebase deployment is separate.

## Validation

Flutter tests cover hint costs and fixed cells, vocabulary, wardrobe purchase/migration, font persistence, mobile result layouts, actual Candy victory/defeat actions and Wordlady outcomes. Node tests cover exact variants and inventory conservation. Local Auth/Firestore/Functions emulator integration checks unrelated-user denial, atomic exchange, repeat acceptance, missing-copy rollback and cancellation:

```
firebase emulators:exec --only auth,firestore,functions --project demo-anivermaru "node tool/firebase_tests/trades.test.cjs"
```
