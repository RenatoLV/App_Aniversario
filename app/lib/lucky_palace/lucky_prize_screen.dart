import 'package:flutter/material.dart';
import '../cat_character.dart';
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
  LuckyPrizeProgress? progress;
  bool busy = true;
  String? error;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LuckyPalette.night,
    appBar: AppBar(title: const Text('Premios de Lucky Palace')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(16),
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
                Icon(prize.icon, color: LuckyPalette.goldLight, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prize.name,
                    style: LuckyPalette.text(21, title: true),
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
