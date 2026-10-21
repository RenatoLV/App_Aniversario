import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'data/lucky_database.dart';
import 'data/local_lucky_wallet.dart';

/// Watches the same committed wallet used by slots, scratch tickets and prizes.
/// The database factory owns the shared handle; this widget only owns its watch.
class CasinoBalanceBadge extends StatefulWidget {
  const CasinoBalanceBadge({super.key, this.database});
  final Database? database;

  @override
  State<CasinoBalanceBadge> createState() => _CasinoBalanceBadgeState();
}

class _CasinoBalanceBadgeState extends State<CasinoBalanceBadge> {
  late final Future<Stream<RecordSnapshot<String, Map<String, Object?>>?>>
  watch = _watch();

  Future<Stream<RecordSnapshot<String, Map<String, Object?>>?>> _watch() async {
    final db = widget.database ?? await openLuckyDatabase();
    return LocalLuckyWallet.record.onSnapshot(db);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: watch,
    builder: (context, source) => StreamBuilder(
      stream: source.data,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.active;
        final value = snapshot.data?.value['balance'];
        final balance = source.hasError || snapshot.hasError || !ready
            ? '—'
            : '${value ?? 500}';
        return Tooltip(
          message: 'Fichas del casino: $balance',
          child: Semantics(
            label: 'Fichas del casino: $balance',
            excludeSemantics: true,
            child: Row(
              key: const ValueKey('casino-balance-badge'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: const Color(0xff813c5b),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffe8bd74),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.pets,
                    color: Color(0xffffe9b7),
                    size: 11,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  balance,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
