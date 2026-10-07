import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../backend.dart';
import 'bomber_simulation.dart';

class BomberNetwork {
  BomberNetwork(this.id, this.sim);
  final String id;
  final BomberSimulation sim;
  final connection = ValueNotifier<String>('Conectando…');
  final subscriptions = <StreamSubscription<DatabaseEvent>>[];
  DatabaseReference get room =>
      FirebaseDatabase.instance.ref('bomberRooms/$id');
  Timer? timer;
  bool writing = false, syncing = false, connected = false, closed = false;
  int lastWrite = 0, lastSync = 0;
  Future<void>? pendingMotion;
  Future<void>? _closing;
  final pendingPowers = <String>{};
  static Future<Map<String, dynamic>> request(
    String action, {
    String? room,
    Map<String, dynamic> extra = const {},
  }) async {
    final token = await Backend.auth.currentUser?.getIdToken();
    if (token == null) throw Exception('Conecta Google para jugar en línea.');
    final response = await http
        .post(
          Uri.parse(
            'https://us-central1-cumplemes.cloudfunctions.net/bomberMatch',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'action': action, 'room': ?room, ...extra}),
        )
        .timeout(const Duration(seconds: 20));
    final body = objectMap(jsonDecode(response.body));
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? 'No se pudo conectar la partida.');
    }
    return body;
  }

  void start() {
    subscriptions.add(
      FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((
        e,
      ) {
        sim.clockOffset = valueNum(e.snapshot.value).toInt();
      }),
    );
    subscriptions.add(
      FirebaseDatabase.instance.ref('.info/connected').onValue.listen((
        e,
      ) async {
        if (closed) return;
        connected = e.snapshot.value == true;
        connection.value = connected ? '' : 'Reconectando… · 10 s de margen';
        if (!connected || closed) {
          sim.input = Offset.zero;
          return;
        }
        try {
          final presence = room.child('presence/${sim.localId}');
          await presence.onDisconnect().set({
            'online': false,
            'at': ServerValue.timestamp,
          });
          if (closed) return;
          await presence.set({'online': true, 'at': ServerValue.timestamp});
          if (closed) return;
          final snapshot = await room.get();
          if (!closed) {
            sim.receive(
              objectMap(jsonDecode(jsonEncode(snapshot.value))),
              resync: true,
            );
          }
        } catch (_) {
          if (!closed) connection.value = 'No pudimos reconectar esta partida.';
        }
      }),
    );
    subscriptions.add(
      room.onValue.listen(
        (event) {
          if (!closed && event.snapshot.exists) {
            sim.receive(
              objectMap(jsonDecode(jsonEncode(event.snapshot.value))),
            );
          }
        },
        onError: (_) {
          if (!closed) {
            connection.value = 'Sin acceso a esta sala. Vuelve al menú.';
          }
        },
      ),
    );
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => pump());
  }

  Future<void> sendMotion() {
    if (writing) return pendingMotion ?? Future.value();
    return pendingMotion = _writeMotion();
  }

  Future<void> _writeMotion() async {
    if (closed ||
        !connected ||
        (!sim.playing && sim.status != 'settling') ||
        !sim.alive(sim.localId) ||
        writing) {
      return;
    }
    writing = true;
    try {
      final p = sim.local,
          velocity = sim.velocities[sim.localId] ?? Offset.zero;
      await room.child('motion/${sim.localId}').set({
        'x': p.dx,
        'y': p.dy,
        'gx': p.dx.floor(),
        'gy': p.dy.floor(),
        'cell': cellKey(p.dx.floor(), p.dy.floor()),
        'vx': velocity.dx,
        'vy': velocity.dy,
        'at': ServerValue.timestamp,
      });
      if (!closed) connection.value = '';
    } catch (_) {
      if (!closed) {
        sim.input = Offset.zero;
        try {
          final snapshot = await room.child('motion/${sim.localId}').get();
          final m = objectMap(snapshot.value);
          if (!closed && m.isNotEmpty) {
            sim.positions[sim.localId] = Offset(
              valueNum(m['x']),
              valueNum(m['y']),
            );
          }
        } catch (_) {}
        if (!closed) connection.value = 'Ajustando la posición…';
      }
    } finally {
      writing = false;
    }
  }

  Future<void> pump() async {
    if (closed || !connected || sim.finished) return;
    unawaited(sendMotion());
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!syncing && now - lastSync > 2000) {
      syncing = true;
      lastSync = now;
      try {
        await request('sync', room: id);
      } catch (_) {
        if (!closed) connection.value = 'Comprobando conexión…';
      } finally {
        syncing = false;
      }
    }
    final k = cellKey(sim.local.dx.floor(), sim.local.dy.floor());
    if (sim.playing && sim.powers.containsKey(k) && pendingPowers.add(k)) {
      try {
        await request('pickup', room: id, extra: {'cell': k});
      } catch (_) {
      } finally {
        pendingPowers.remove(k);
      }
    }
  }

  Future<void> bomb() async {
    if (!connected || !sim.canBomb(sim.localId)) return;
    final position = sim.local;
    final cell = cellKey(position.dx.floor(), position.dy.floor());
    if (writing) await pendingMotion;
    if (closed || !connected || !sim.canBomb(sim.localId)) return;
    await sendMotion();
    final random = Random.secure(),
        nonce = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await request('bomb', room: id, extra: {'id': nonce, 'cell': cell});
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    closed = true;
    timer?.cancel();
    for (final s in subscriptions) {
      await s.cancel();
    }
    try {
      await room.child('presence/${sim.localId}').set({
        'online': false,
        'at': ServerValue.timestamp,
      });
      await room.child('presence/${sim.localId}').onDisconnect().cancel();
    } catch (_) {}
    connection.dispose();
  }
}
