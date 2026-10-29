import 'package:flutter/material.dart';

class LuckyChipPack {
  const LuckyChipPack(
    this.id,
    this.name,
    this.chips,
    this.coinCost,
    this.icon,
  );
  final String id, name;
  final int chips, coinCost;
  final IconData icon;
}

/// Buying chips with coins is intentionally priced higher in coins-per-chip
/// (3.0 to 4.0 coins per chip) than the one-time chip-to-coin prizes.
const luckyChipPacks = [
  LuckyChipPack(
    'pack_50',
    'Bolsa de fichas',
    50,
    200,
    Icons.toll_rounded,
  ),
  LuckyChipPack(
    'pack_150',
    'Montón de fichas',
    150,
    525,
    Icons.generating_tokens_rounded,
  ),
  LuckyChipPack(
    'pack_400',
    'Cofre VIP de fichas',
    400,
    1200,
    Icons.diamond_rounded,
  ),
];

class LuckyPrize {
  const LuckyPrize(
    this.id,
    this.name,
    this.description,
    this.cost,
    this.games,
    this.icon, {
    this.coins = 0,
    this.clothingId,
  });
  final String id, name, description;
  final int cost, games, coins;
  final IconData icon;
  final String? clothingId;
  String get claimId => 'casino.prize.v1:$id';
}

final luckyPrizes = [
  LuckyPrize(
    'welcome',
    'Primer brindis',
    '200 monedas para gastar en la app.',
    75,
    5,
    Icons.monetization_on_rounded,
    coins: 200,
  ),
  LuckyPrize(
    'charm',
    'Amuleto de la suerte',
    'Collar esmeralda con una patita de oro. Exclusivo para Maru y Lady.',
    150,
    10,
    Icons.pets_rounded,
    clothingId: 'casino_charm',
  ),
  LuckyPrize(
    'suit',
    'Traje Royal Maru',
    'Traje color vino con solapas doradas y pajarita. Exclusivo del casino.',
    300,
    20,
    Icons.checkroom_rounded,
    clothingId: 'casino_suit',
  ),
  LuckyPrize(
    'crown',
    'Corona Lucky Palace',
    'Corona de oro con esmeraldas y una estrella central. Para tus dos monitos.',
    600,
    35,
    Icons.workspace_premium_rounded,
    clothingId: 'casino_crown',
  ),
  LuckyPrize(
    'grand',
    'Tesoro del palacio',
    '1200 monedas para celebrar tu recorrido por Lucky Palace.',
    900,
    50,
    Icons.card_giftcard_rounded,
    coins: 1200,
  ),
  LuckyPrize(
    'starlight',
    'Gafas Estrella de la noche',
    'Montura de estrellas doradas con pequeños rubíes. Exclusivas para tus monitos.',
    220,
    15,
    Icons.auto_awesome_rounded,
    clothingId: 'casino_starlight',
  ),
  LuckyPrize(
    'love',
    'Medallón Maruzonita',
    'Un corazón de rubí entre perlas, para llevar nuestro aniversario cerquita.',
    420,
    25,
    Icons.favorite_rounded,
    clothingId: 'casino_love',
  ),
  LuckyPrize(
    'confetti',
    'Traje Noche de confeti',
    'Traje violeta con estrellas, confeti de oro y pajarita rosa. Edición aniversario.',
    750,
    40,
    Icons.celebration_rounded,
    clothingId: 'casino_confetti',
  ),
  LuckyPrize(
    'anniversary',
    'Cofre del primer año',
    '2000 monedas y un recuerdo de todas tus partidas. Canje único.',
    1500,
    75,
    Icons.redeem_rounded,
    coins: 2000,
  ),
]..sort((a, b) => a.games.compareTo(b.games));

LuckyPrize luckyPrize(String id) => luckyPrizes.firstWhere((p) => p.id == id);
