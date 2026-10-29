import 'package:flutter/material.dart';
import '../cat_character.dart';
import '../cat_clothing.dart';
import '../store.dart';
import 'data/lucky_database.dart';
import 'data/lucky_prize_repository.dart';
import 'data/local_lucky_repository.dart';
import 'lucky_prizes.dart';
import 'lucky_palace_theme.dart';

class LuckyPrizeScreen extends StatefulWidget {
  const LuckyPrizeScreen({
    super.key,
    required this.storage,
    required this.store,
  });
  final LuckyDatabase storage;
  final GameStore store;
  @override
  State<LuckyPrizeScreen> createState() => _LuckyPrizeScreenState();
}

class _LuckyPrizeScreenState extends State<LuckyPrizeScreen> {
  late final owner = widget.store.casinoPrizeOwner;
  late final repo = LuckyPrizeRepository(widget.storage, owner);
  final _showcaseKey = GlobalKey();
  LuckyPrizeProgress? progress;
  bool busy = true;
  String? error;

  // Interactive VIP showroom state (rotation + live outfit try-on).
  double _turn = 0;
  CatOutfit _tryOutfit = const CatOutfit(
    head: 'casino_crown',
    eyes: 'casino_starlight',
    neck: 'casino_love',
    body: 'casino_suit',
  );
  String? _tryingLabel = 'Gala Lucky Palace';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _checkOwner() {
    if (widget.store.casinoPrizeOwner != owner) {
      throw StateError('La cuenta cambió. Vuelve a abrir Premios.');
    }
  }

  Future<void> _load() async {
    try {
      final next = await repo.progress();
      _checkOwner();
      for (final id in next.claimed) {
        if (luckyPrizes.any((p) => p.id == id) &&
            (!widget.store.ownsCasinoPrize(id) ||
                widget.store.saveError != null)) {
          await widget.store.deliverCasinoPrize(id);
          _checkOwner();
        }
      }
      if (mounted) {
        setState(() {
          progress = next;
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se pudo confirmar el premio. Tu canje se conserva. $e';
        });
      }
    }
  }

  Future<void> _buyChipPack(LuckyChipPack pack) async {
    if (busy) return;
    if (widget.store.coins < pack.coinCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Necesitas ${pack.coinCost} monedas para comprar ${pack.chips} fichas.',
          ),
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final spent = await widget.store.spendCoinsForCasinoChips(pack.coinCost);
    if (!spent) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se pudieron descontar las monedas. Inténtalo de nuevo.';
        });
      }
      return;
    }
    try {
      _checkOwner();
      await repo.creditPurchasedChips(pack.chips, coinCost: pack.coinCost);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Compraste +${pack.chips} fichas por ${pack.coinCost} monedas!',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      await widget.store.refundCasinoChipCoins(pack.coinCost);
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se completó la compra de fichas; tus monedas se conservaron. $e';
        });
      }
    }
  }

  Future<void> _redeem(LuckyPrize prize) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      _checkOwner();
      if (!widget.store.ownsCasinoPrize(prize.id)) await repo.redeem(prize.id);
      _checkOwner();
      await widget.store.deliverCasinoPrize(prize.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prize.clothingId == null
                  ? '¡${prize.coins} monedas añadidas a tu monedero!'
                  : '¡${prize.name} ya está en el probador de la casita!',
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'No se completó la entrega. Reintenta para recuperarla sin otro cobro. $e';
        });
      }
    }
  }

  Future<void> _refill() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await LocalLuckyRoundRepository(widget.storage).refill();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'No se pudo recargar: $e';
        });
      }
    }
  }

  void _previewPrizeOnStage(CatClothing garment, String label) {
    setState(() {
      _tryOutfit = _tryOutfit.withItem(garment.slot, garment.id);
      _tryingLabel = label;
    });
    final ctx = _showcaseKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _vipShowcase() {
    return Container(
      key: _showcaseKey,
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff9f7a46), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff382548), Color(0xff23172e)],
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'PASARELA VIP · ${_tryingLabel ?? 'Vista previa'}',
                style: LuckyPalette.text(14, title: true),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  if (_tryingLabel == 'Conjunto actual') {
                    _tryOutfit = const CatOutfit(
                      head: 'casino_crown',
                      eyes: 'casino_starlight',
                      neck: 'casino_love',
                      body: 'casino_suit',
                    );
                    _tryingLabel = 'Gala Lucky Palace';
                  } else {
                    _tryOutfit = const CatOutfit();
                    _tryingLabel = 'Conjunto actual';
                  }
                }),
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: LuckyPalette.goldLight,
                ),
                label: Text(
                  _tryingLabel == 'Conjunto actual'
                      ? 'Ver Gala VIP'
                      : 'Sin accesorios VIP',
                  style: const TextStyle(
                    color: LuckyPalette.goldLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() {
              _turn = (_turn + d.delta.dx / 110).clamp(-1.0, 1.0);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final cat in CatKind.values)
                    CatActor(
                      cat: cat,
                      size: 112,
                      turn: _turn,
                      outfit: _tryingLabel == 'Conjunto actual'
                          ? widget.store.catCare.outfit(cat)
                          : _tryOutfit,
                      showLabel: false,
                      sleeping: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          _VipTurnControls(
            turn: _turn,
            onChanged: (next) => setState(() => _turn = next),
          ),
          const SizedBox(height: 4),
          Text(
            'Desliza sobre Maru y Lady o usa los botones para girarlos en 360°.',
            textAlign: TextAlign.center,
            style: LuckyPalette.text(11),
          ),
        ],
      ),
    );
  }

  Widget _chipExchangeBox() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff2a1e36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff73573b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.currency_exchange_rounded,
                color: LuckyPalette.goldLight,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAJERO DE FICHAS · Monedas: ${widget.store.coins} 🪙',
                  style: LuckyPalette.text(16, title: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cambia tus monedas por fichas para jugar más (tasa de cambio más alta en monedas por ficha).',
            style: LuckyPalette.text(12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pack in luckyChipPacks)
                FilledButton.tonalIcon(
                  key: ValueKey('buy-chips-${pack.chips}'),
                  onPressed: busy || widget.store.coins < pack.coinCost
                      ? null
                      : () => _buyChipPack(pack),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff47315a),
                    foregroundColor: LuckyPalette.goldLight,
                  ),
                  icon: Icon(pack.icon, size: 17),
                  label: Text('+${pack.chips} fichas · ${pack.coinCost} 🪙'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LuckyPalette.night,
    appBar: AppBar(title: const Text('Premios de Lucky Palace')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'EL TESORO DE MARU Y LADY',
                  style: LuckyPalette.text(23, title: true),
                ),
                const SizedBox(height: 8),
                Text(
                  'Juega, reúne fichas y llévate premios únicos. Cada giro de pago y cada raspe revelado suma una partida, ganes o pierdas. Los giros gratis no suman partidas.',
                  style: LuckyPalette.text(15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.toll),
                      label: Text('${progress?.balance ?? '…'} fichas'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.monetization_on_outlined),
                      label: Text('${widget.store.coins} monedas'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.casino),
                      label: Text('${progress?.games ?? '…'} partidas'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.check_circle_outline),
                      label: Text(
                        '${luckyPrizes.where((p) => widget.store.ownsCasinoPrize(p.id)).length}/${luckyPrizes.length} premios',
                      ),
                    ),
                  ],
                ),
                Text(
                  'Las monedas van a tu monedero. Las prendas se pueden equipar en la casita y quedan disponibles para ambos gatos. Cada premio se canjea una sola vez.',
                  style: LuckyPalette.text(13),
                ),
                _vipShowcase(),
                _chipExchangeBox(),
                if (progress != null && progress!.balance < 25)
                  TextButton.icon(
                    onPressed: busy ? null : _refill,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'Recargar gratis +500 fichas para seguir jugando',
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: Colors.amber)),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() => busy = true);
                            _load();
                          },
                    child: const Text('Reintentar entrega'),
                  ),
                ],
                for (final prize in luckyPrizes) _card(prize),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _card(LuckyPrize prize) {
    final owned = widget.store.ownsCasinoPrize(prize.id);
    final paid = progress?.claimed.contains(prize.id) ?? false;
    final games = progress?.games ?? 0;
    final unlocked = games >= prize.games;
    final affordable = (progress?.balance ?? 0) >= prize.cost;
    final garment = clothingById(prize.clothingId);
    final outfit = garment == null
        ? const CatOutfit()
        : const CatOutfit().withItem(garment.slot, garment.id);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: const Color(0xff30233c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: owned ? const Color(0xff53cbae) : const Color(0xff806240),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (garment != null)
                  ClothingPreviewIcon(item: garment, size: 36)
                else
                  Icon(prize.icon, color: LuckyPalette.goldLight, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prize.name,
                    style: LuckyPalette.text(21, title: true),
                  ),
                ),
                if (garment != null)
                  IconButton(
                    key: ValueKey('try-prize-${prize.id}'),
                    tooltip: 'Probar en pasarela VIP',
                    onPressed: () => _previewPrizeOnStage(garment, prize.name),
                    icon: const Icon(
                      Icons.threesixty_rounded,
                      color: LuckyPalette.goldLight,
                    ),
                  ),
              ],
            ),
            if (garment != null)
              SizedBox(
                height: 112,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final cat in CatKind.values)
                      CatActor(
                        cat: cat,
                        size: 104,
                        turn: _turn,
                        outfit: outfit,
                        showLabel: false,
                        sleeping: false,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(prize.description, style: LuckyPalette.text(15)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (games / prize.games).clamp(0, 1),
              color: LuckyPalette.goldLight,
            ),
            const SizedBox(height: 6),
            Text(
              '$games/${prize.games} partidas · ${prize.cost} fichas · Premio único',
              style: LuckyPalette.text(13),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: ValueKey('prize-${prize.id}'),
              onPressed: busy || owned || !(paid || unlocked && affordable)
                  ? null
                  : () => _redeem(prize),
              icon: Icon(
                owned
                    ? Icons.check_circle
                    : !unlocked
                    ? Icons.lock_outline
                    : Icons.redeem,
              ),
              label: Text(
                owned
                    ? 'Conseguido'
                    : paid
                    ? 'Recuperar premio'
                    : !unlocked
                    ? 'Faltan ${prize.games - games} partidas'
                    : !affordable
                    ? 'Faltan ${prize.cost - (progress?.balance ?? 0)} fichas'
                    : 'Canjear por ${prize.cost} fichas',
              ),
            ),
            if (owned && garment != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        for (final cat in CatKind.values) {
                          if (widget.store.catCare
                                  .outfit(cat)
                                  .at(garment.slot) !=
                              garment.id) {
                            await widget.store.catCare.equip(cat, garment);
                          }
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Maru y Lady ya lucen su premio!'),
                            ),
                          );
                        }
                      },
                child: const Text('Vestir a Maru y Lady'),
              ),
          ],
        ),
      ),
    );
  }
}

class _VipTurnControls extends StatelessWidget {
  final double turn;
  final ValueChanged<double> onChanged;
  const _VipTurnControls({required this.turn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isBack = turn.abs() > 0.65;
    final isProfile = !isBack && turn.abs() >= 0.25;
    final isFront = !isBack && !isProfile;

    Widget pill(String label, double target, bool selected) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff5a3c74) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: LuckyPalette.goldLight,
          ),
        ),
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xff241730),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff806240)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final next = turn - 0.45;
                onChanged(next < -1.0 ? 1.0 : next.clamp(-1.0, 1.0));
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(
                  Icons.rotate_left_rounded,
                  size: 17,
                  color: LuckyPalette.goldLight,
                ),
              ),
            ),
            pill('Frente', 0.0, isFront),
            pill('Perfil', 0.48, isProfile),
            pill('Espalda', 1.0, isBack),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final next = turn + 0.45;
                onChanged(next > 1.0 ? -1.0 : next.clamp(-1.0, 1.0));
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(
                  Icons.rotate_right_rounded,
                  size: 17,
                  color: LuckyPalette.goldLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
