'use strict';
const rarities = ['common', 'epic', 'legendary', 'uncommon', 'rare', 'mythic'];
const ranks = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];
function variant(key) {
  if (typeof key !== 'string' || !/^\d+:(common|uncommon|rare|epic|legendary|mythic):(normal|silver|gold)$/.test(key))
    throw Error('Elige una variante válida de la carta.');
  const [id, rarity, finish] = key.split(':');
  return {id, rarity, finish};
}
function unpack(doc) {
  if (!doc?.payload) throw Error('Sincroniza tu progreso antes de intercambiar.');
  const payload = JSON.parse(doc.payload);
  const core = JSON.parse(payload['rincon.v1']);
  core.cardVariants ||= {};
  if (!Object.keys(core.cardVariants).length) {
    for (const [id, count] of Object.entries(core.cards || {}))
      core.cardVariants[`${id}:${rarities[core.rarities?.[id] || 0]}:normal`] = count;
  }
  return {payload, core};
}
function owns(core, key) {
  variant(key);
  return Number.isSafeInteger(core.cardVariants[key]) && core.cardVariants[key] > 0;
}
function rebuild(core) {
  const cards = {}, best = {};
  for (const [key, count] of Object.entries(core.cardVariants)) {
    if (!Number.isSafeInteger(count) || count < 0) throw Error('Inventario inválido.');
    if (!count) { delete core.cardVariants[key]; continue; }
    const v = variant(key);
    cards[v.id] = (cards[v.id] || 0) + count;
    if (best[v.id] === undefined || ranks.indexOf(v.rarity) > ranks.indexOf(rarities[best[v.id]])) best[v.id] = rarities.indexOf(v.rarity);
  }
  core.cards = cards; core.rarities = best;
}
function transfer(fromDoc, toDoc, give, receive, tradeId) {
  const from = unpack(fromDoc), to = unpack(toDoc);
  if (give === receive) throw Error('Elige dos cartas distintas.');
  if (!owns(from.core, give) || !owns(to.core, receive))
    throw Error('Una de las cartas ya no está disponible.');
  for (const [player, outgoing, incoming, other] of [[from, give, receive, to], [to, receive, give, from]]) {
    const id = variant(incoming).id;
    player.core.cardVariants[outgoing]--;
    player.core.cardVariants[incoming] = (player.core.cardVariants[incoming] || 0) + 1;
    player.core.cardOpeners ||= {}; player.core.cardCollections ||= {};
    player.core.cardOpeners[id] ??= other.core.cardOpeners?.[id] ?? 0;
    if (other.core.cardCollections?.[id]) player.core.cardCollections[id] = other.core.cardCollections[id];
    player.core.tradeReceipts ||= {};
    player.core.tradeReceipts[tradeId] = {outgoing, incoming,
      opener: other.core.cardOpeners?.[id] ?? 0, collection: other.core.cardCollections?.[id] ?? null};
    rebuild(player.core);
    player.payload['rincon.v1'] = JSON.stringify(player.core);
  }
  return [JSON.stringify(from.payload), JSON.stringify(to.payload)];
}
module.exports = {variant, unpack, owns, rebuild, transfer};
