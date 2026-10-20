import 'dart:convert';
import 'dart:io';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';

// Generates authoritative cross-runtime fixtures from the unchanged Dart engine.
// Node's crypto only hashes the output stream; it does not evaluate Dart results.
Future<void> main() async {
  final a = LuckyRules.candidate;
  final b = LuckyRules(
    catalogVersion: a.catalogVersion,
    rulesVersion: 'lucky777.rules.audit.stake10.v1',
    reels: a.reels,
    payouts: a.payouts,
    lines: a.lines,
    lineStake: 2,
  );
  Map<String, Object> configuration(LuckyRules r) => {
    'catalogVersion': r.catalogVersion,
    'rulesVersion': r.rulesVersion,
    'lineStake': r.lineStake,
    'maxBonusSpins': r.maxBonusSpins,
    'reels': r.reels.map((row) => row.map((s) => s.name).toList()).toList(),
    'lines': r.lines.map((l) => {'id': l.id, 'rows': l.rows}).toList(),
    'payouts': r.payouts.map(
      (k, v) => MapEntry(k.name, v.map((n, p) => MapEntry('$n', p))),
    ),
    'scatterAwards': r.scatterAwards.map((k, v) => MapEntry('$k', v)),
  };
  final rulesFile = File('functions/economy_v2/casino/rules.json');
  rulesFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'reference25': configuration(a), 'scaled10': configuration(b)})}\n',
  );
  final results = <String, Object>{};
  for (final entry in {'reference25': a, 'scaled10': b}.entries) {
    final engine = LuckyEngine(entry.value);
    final process = await Process.start('node', [
      '-e',
      "const c=require('crypto').createHash('sha256');process.stdin.on('data',x=>c.update(x));process.stdin.on('end',()=>process.stdout.write(c.digest('hex')));",
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final histogram = <String, int>{};
    for (var n = 0; n < 1048576; n++) {
      final stops = List.generate(5, (c) => (n >> (4 * (4 - c))) & 15);
      final round = engine.evaluateStops(stops);
      process.stdin.writeln(jsonEncode(round.toJson()));
      final key =
          '${round.evaluation.total}:${round.evaluation.scatterColumns.length}';
      histogram[key] = (histogram[key] ?? 0) + 1;
      if (n % 2048 == 0) await process.stdin.flush();
    }
    await process.stdin.close();
    if (await process.exitCode != 0) throw StateError(await errors);
    final fixtures = <Object>[];
    for (final stops in [
      [14, 6, 3, 9, 10],
      [6, 11, 8, 5, 13],
      [0, 0, 0, 0, 0],
    ]) {
      for (final before in [
        const LuckyBonusState(),
        const LuckyBonusState(remaining: 1, awarded: 49),
        const LuckyBonusState(remaining: 50, awarded: 50),
        const LuckyBonusState(remaining: 0, awarded: 50),
      ]) {
        fixtures.add({
          'before': {'remaining': before.remaining, 'awarded': before.awarded},
          'round': engine.evaluateStops(stops, bonus: before).toJson(),
        });
      }
    }
    final random = LuckySeededRandom(20261019);
    for (var i = 0; i < 100; i++) {
      final before = LuckyBonusState(remaining: i % 7, awarded: 6 + i % 45);
      fixtures.add({
        'before': {'remaining': before.remaining, 'awarded': before.awarded},
        'round': engine.spin(random, bonus: before).toJson(),
      });
    }
    results[entry.key] = {
      'stopsCount': 1048576,
      'roundsSha256': await output,
      'histogram': histogram,
      'fixtures': fixtures,
    };
    stdout.writeln('${entry.key}: full Dart enumeration complete');
  }
  // All 9^5 single-line inputs include ambiguous Wild prefixes and Scatter.
  final lines = await Process.start('node', [
    '-e',
    "const c=require('crypto').createHash('sha256');process.stdin.on('data',x=>c.update(x));process.stdin.on('end',()=>process.stdout.write(c.digest('hex')));",
  ]);
  final hash = lines.stdout.transform(utf8.decoder).join();
  final lineErrors = lines.stderr.transform(utf8.decoder).join();
  for (var n = 0; n < 59049; n++) {
    var value = n;
    final symbols = List<LuckySymbol>.filled(5, LuckySymbol.yarn);
    for (var c = 4; c >= 0; c--) {
      symbols[c] = LuckySymbol.values[value % 9];
      value ~/= 9;
    }
    final win = LuckyEngine(a).evaluateLine(symbols);
    lines.stdin.writeln(
      jsonEncode(
        win == null
            ? null
            : {
                'id': win.line.id,
                'symbol': win.symbol.name,
                'count': win.count,
                'multiplier': win.multiplier,
                'amount': win.amount,
              },
      ),
    );
    if (n % 2048 == 0) await lines.stdin.flush();
  }
  await lines.stdin.close();
  if (await lines.exitCode != 0) throw StateError(await lineErrors);
  results['lines'] = {'count': 59049, 'sha256': await hash};
  File('tool/lucky_server_parity.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
  );
}
