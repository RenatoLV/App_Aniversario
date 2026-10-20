const scratchAssetRoot = 'assets/lucky_palace/scratch';
const scratchSymbolNames = {
  'paw': 'Patita',
  'fish': 'Pescado',
  'ball_yarn': 'Ovillo',
  'churu': 'Churu',
  'bell': 'Cascabel',
  'clover': 'Trébol',
  'coin': 'Moneda',
  'gem': 'Gema',
  'chest': 'Cofre',
  'candy': 'Dulce',
  'heart': 'Corazón',
  'flower': 'Flor',
  'crown': 'Corona',
  'star': 'Estrella',
  'moon': 'Luna',
  'lantern': 'Farol',
  'seven': 'Siete',
  'wild': 'Comodín',
  'scratch_ticket': 'Boleto',
};

class ScratchTheme {
  const ScratchTheme(
    this.id,
    this.title,
    this.subtitle,
    this.accent,
    this.symbols,
  );
  final String id, title, subtitle;
  final int accent;
  final List<String> symbols;
  String asset(String layer) => '$scratchAssetRoot/tickets/$id/$layer.png';
  static const all = [
    ScratchTheme(
      'patita_suerte',
      'Patita de la Suerte',
      'Un toque de fortuna',
      0xffffd67a,
      ['paw', 'fish', 'ball_yarn', 'churu', 'bell', 'clover'],
    ),
    ScratchTheme('tesoros_maru', 'Tesoros de Maru', 'Bajo el mar', 0xffffe39d, [
      'fish',
      'ball_yarn',
      'bell',
      'coin',
      'gem',
      'chest',
    ]),
    ScratchTheme(
      'dulces_lady',
      'Dulces de Lady',
      'Una sorpresa deliciosa',
      0xffffe2a0,
      ['candy', 'heart', 'churu', 'flower', 'bell', 'crown'],
    ),
    ScratchTheme(
      'estrellas_suerte',
      'Estrellas de la Suerte',
      'Pide un deseo',
      0xffffe7a2,
      ['star', 'moon', 'bell', 'coin', 'gem', 'crown'],
    ),
    ScratchTheme(
      'festival_felino',
      'Festival Felino',
      'Luces, flores y suerte',
      0xffffe09a,
      ['flower', 'lantern', 'paw', 'churu', 'bell', 'star'],
    ),
  ];
  static ScratchTheme byId(String id) => all.firstWhere(
    (t) => t.id == id,
    orElse: () => throw const FormatException('Tema de raspe desconocido'),
  );
}
