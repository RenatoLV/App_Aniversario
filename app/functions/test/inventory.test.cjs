const {test} = require('node:test');
const assert = require('node:assert/strict');
const {transfer, unpack} = require('../inventory.cjs');
function doc(variants, coins = 500) {
  return {payload: JSON.stringify({'rincon.v1': JSON.stringify({coins,
    cardVariants: variants, cards: {}, rarities: {}, cardOpeners: {}, cardCollections: {},
    catCare: {kept: true}}), 'wordle.v1': 'unchanged'}), revision: 4};
}
test('Swap one precise foil and preserve all other progress', () => {
  const a = doc({'1:mythic:silver': 2, '1:rare:normal': 1});
  const b = doc({'2:legendary:gold': 1}, 777);
  const [a2, b2] = transfer(a, b, '1:mythic:silver', '2:legendary:gold', 'trade');
  const ac = unpack({payload:a2}).core, bc = unpack({payload:b2}).core;
  assert.deepEqual(ac.cardVariants, {'1:mythic:silver':1, '1:rare:normal':1, '2:legendary:gold':1});
  assert.deepEqual(bc.cardVariants, {'1:mythic:silver':1});
  assert.deepEqual(ac.cards, {'1':2,'2':1});
  assert.deepEqual(ac.rarities, {'1':5,'2':2});
  assert.equal(bc.coins, 777); assert.deepEqual(ac.catCare, {kept:true});
  assert.equal(JSON.parse(a2)['wordle.v1'], 'unchanged');
  assert.equal(ac.tradeReceipts.trade.outgoing, '1:mythic:silver');
});
test('Missing copies, invalid variants and self swaps are rejected without mutation', () => {
  const a=doc({'1:rare:normal':1}), b=doc({'2:epic:normal':1});
  const saved=JSON.stringify([a,b]);
  assert.throws(() => transfer(a,b,'1:rare:gold','2:epic:normal','x'), /disponible/);
  assert.throws(() => transfer(a,b,'1:rare:normal','1:rare:normal','x'), /distintas/);
  assert.throws(() => transfer(a,b,'1:rare:foil','2:epic:normal','x'), /válida/);
  assert.equal(JSON.stringify([a,b]), saved);
});
test('Celestial GIF cards swap exact copies and retain the appended rarity index', () => {
  const [a, b] = transfer(doc({'10000:celestial:gold': 2}),
    doc({'10001:celestial:normal': 1}), '10000:celestial:gold', '10001:celestial:normal', 'celestial');
  const ac = unpack({payload:a}).core, bc = unpack({payload:b}).core;
  assert.deepEqual(ac.cardVariants, {'10000:celestial:gold': 1, '10001:celestial:normal': 1});
  assert.deepEqual(bc.cardVariants, {'10000:celestial:gold': 1});
  assert.deepEqual(ac.rarities, {'10000': 6, '10001': 6});
  assert.equal(ac.coins, 500);
});
