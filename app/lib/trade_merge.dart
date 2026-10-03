import 'dart:convert';

/// Reapply server trade receipts to unsynced local progress exactly once.
/// Coins, games, care and notes remain from the device's current snapshot.
String mergeTradeReceipts(String local, String remote) {
  final a = jsonDecode(local) as Map<String, dynamic>;
  final b = jsonDecode(remote) as Map<String, dynamic>;
  if (a['rincon.v1'] is! String || b['rincon.v1'] is! String) return local;
  final core = jsonDecode(a['rincon.v1']) as Map<String, dynamic>;
  final server = jsonDecode(b['rincon.v1']) as Map<String, dynamic>;
  final receipts = Map<String, dynamic>.from(core['tradeReceipts'] ?? {});
  final pending = Map<String, dynamic>.from(server['tradeReceipts'] ?? {})
    ..removeWhere((id, _) => receipts.containsKey(id));
  if (pending.isEmpty) return local;
  final variants = Map<String, dynamic>.from(core['cardVariants'] ?? {});
  final openers = Map<String, dynamic>.from(core['cardOpeners'] ?? {});
  final collections = Map<String, dynamic>.from(core['cardCollections'] ?? {});
  for (final receipt in pending.values) {
    final out = receipt['outgoing'] as String,
        incoming = receipt['incoming'] as String;
    variants[out] = (variants[out] as int? ?? 0) - 1;
    variants[incoming] = (variants[incoming] as int? ?? 0) + 1;
    final id = incoming.split(':').first;
    openers[id] ??= receipt['opener'] ?? 0;
    if (receipt['collection'] != null) collections[id] = receipt['collection'];
  }
  if (variants.values.any((v) => (v as int) < 0)) {
    throw StateError(
      'Hay cartas distintas en este dispositivo. Recupera el progreso de tu cuenta.',
    );
  }
  variants.removeWhere((_, count) => count == 0);
  const names = [
    'common',
    'epic',
    'legendary',
    'uncommon',
    'rare',
    'mythic',
    'celestial',
  ];
  const ranks = [
    'common',
    'uncommon',
    'rare',
    'epic',
    'legendary',
    'mythic',
    'celestial',
  ];
  final counts = <String, int>{}, rarities = <String, int>{};
  for (final entry in variants.entries) {
    final parts = entry.key.split(':');
    final id = parts[0], rarity = parts[1];
    counts[id] = (counts[id] ?? 0) + (entry.value as int);
    if (!rarities.containsKey(id) ||
        ranks.indexOf(rarity) > ranks.indexOf(names[rarities[id]!])) {
      rarities[id] = names.indexOf(rarity);
    }
  }
  core.addAll({
    'cardVariants': variants,
    'cards': counts,
    'rarities': rarities,
    'cardOpeners': openers,
    'cardCollections': collections,
    'tradeReceipts': receipts..addAll(pending),
  });
  a['rincon.v1'] = jsonEncode(core);
  return jsonEncode(a);
}
