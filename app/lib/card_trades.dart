import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'backend.dart';
import 'bloc_people.dart';
import 'paw_background.dart';
import 'store.dart';

class CardTrades {
  static Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    if (Backend.uid == null) throw StateError('Inicia sesión con Google.');
    final token = await Backend.auth.currentUser!.getIdToken();
    final response = await http
        .post(
          Uri.parse(
            'https://us-central1-cumplemes.cloudfunctions.net/cardTrades',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('El servicio de intercambios no está disponible.');
    }
    if (response.statusCode != 200) {
      throw StateError(
        data['error'] as String? ?? 'No se pudo completar el intercambio.',
      );
    }
    return data;
  }

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class CardTradeScreen extends StatefulWidget {
  final GameStore store;
  const CardTradeScreen({super.key, required this.store});
  @override
  State<CardTradeScreen> createState() => _CardTradeScreenState();
}

class _CardTradeScreenState extends State<CardTradeScreen> {
  String search = '';
  bool busy = false;
  Future<void> act(Future<void> Function() task, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> view(String uid) => act(() async {
    final data = await CardTrades.call({'action': 'view', 'target': uid});
    if (!mounted) return;
    final variants = Map<String, dynamic>.from(data['variants'] ?? {})
      ..removeWhere((_, copies) => (copies as int) <= 0);
    final wanted = await showDialog<String>(
      context: context,
      builder: (context) => _PickTradeCard(
        title: 'Colección de ${data['name']}',
        variants: variants,
      ),
    );
    if (wanted == null || !mounted) return;
    await widget.store.cloud.flushForTrade();
    if (!mounted) return;
    final own = Map<String, dynamic>.from(widget.store.cardVariants)
      ..removeWhere((key, copies) => copies <= 0 || key == wanted);
    if (own.isEmpty) {
      throw StateError('Necesitas otra carta para ofrecer a cambio.');
    }
    final offer = await showDialog<String>(
      context: context,
      builder: (context) =>
          _PickTradeCard(title: '¿Qué carta ofreces?', variants: own),
    );
    if (offer == null || !mounted) return;
    final confirmed = await confirm(
      offer,
      wanted,
      'Enviar propuesta',
      'Ofreces una copia de tu carta por una de su colección. La otra persona debe aceptar.',
    );
    if (!confirmed) return;
    await CardTrades.call({
      'action': 'propose',
      'target': uid,
      'give': offer,
      'receive': wanted,
      'id': CardTrades.newId(),
    });
  }, 'Colección revisada');

  Future<bool> confirm(
    String give,
    String receive,
    String title,
    String detail,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(detail),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _TradeCard(variant: give, label: 'Entregas'),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.swap_horiz),
                    ),
                    Expanded(
                      child: _TradeCard(variant: receive, label: 'Recibes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> respond(
    String id,
    Map<String, dynamic> request,
    String choice,
  ) => act(() async {
    if (choice == 'accept') {
      if (!await confirm(
        request['receive'],
        request['give'],
        'Aceptar intercambio',
        'Se intercambia una copia de cada carta, con la variante que ves aquí.',
      )) {
        return;
      }
      await widget.store.cloud.flushForTrade();
    }
    await CardTrades.call({'action': 'respond', 'id': id, 'choice': choice});
    await widget.store.cloud.flushForTrade();
  }, choice == 'accept' ? '¡Intercambio completado!' : 'Solicitud actualizada');

  Widget requests(
    bool incoming,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: Backend.db
        .collection('card_trades')
        .where(incoming ? 'toUid' : 'fromUid', isEqualTo: Backend.uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('No se pudieron cargar las solicitudes.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList()
        ..sort(
          (a, b) =>
              ((b.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                    (a.data()['updatedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0,
                  ),
        );
      if (docs.isEmpty) {
        return const Center(child: Text('Todavía no hay propuestas 🐾'));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final doc in docs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      incoming
                          ? '${doc.data()['name']} te propone'
                          : 'Tu propuesta',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TradeCard(
                            variant: doc.data()[incoming ? 'receive' : 'give'],
                            label: 'Entregas',
                          ),
                        ),
                        const Icon(Icons.swap_horiz),
                        Expanded(
                          child: _TradeCard(
                            variant: doc.data()[incoming ? 'give' : 'receive'],
                            label: 'Recibes',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (doc.data()['status'] == 'pending')
                      Wrap(
                        spacing: 8,
                        children: [
                          if (incoming)
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => respond(doc.id, doc.data(), 'accept'),
                              icon: const Icon(Icons.check),
                              label: const Text('Aceptar'),
                            ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => respond(
                                    doc.id,
                                    doc.data(),
                                    incoming ? 'reject' : 'cancel',
                                  ),
                            child: Text(
                              incoming ? 'Rechazar' : 'Cancelar propuesta',
                            ),
                          ),
                        ],
                      )
                    else
                      Text(switch (doc.data()['status']) {
                        'accepted' => 'Intercambio completado ✓',
                        'rejected' => 'Rechazada',
                        'cancelled' => 'Cancelada',
                        _ => 'Pendiente',
                      }),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Intercambiar cartas'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Jugadores'),
            Tab(text: 'Recibidas'),
            Tab(text: 'Enviadas'),
          ],
        ),
      ),
      body: PawBackground(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Comparte tus recuerdos y encuentra la carta que te falta.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => act(
                                      () async {
                                        await widget.store.cloud
                                            .flushForTrade();
                                        await CardTrades.call({
                                          'action': 'publish',
                                        });
                                      },
                                      'Tu colección está disponible para intercambios',
                                    ),
                              icon: const Icon(Icons.style),
                              label: const Text('Compartir mi colección'),
                            ),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => search = value),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Buscar por nombre en la app',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: BlocPeople.people(search),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      'No se pudieron cargar los jugadores.',
                                    ),
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final docs = snapshot.data!.docs
                                    .where((d) => d.id != Backend.uid)
                                    .toList();
                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No encontramos otros jugadores.',
                                    ),
                                  );
                                }
                                return ListView(
                                  children: [
                                    for (final doc in docs)
                                      ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.pets),
                                        ),
                                        title: Text(
                                          doc.data()['name'] ?? 'Jugador',
                                        ),
                                        subtitle: const Text(
                                          'Ver colección y proponer intercambio',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: busy ? null : () => view(doc.id),
                                      ),
                                  ],
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                  requests(true),
                  requests(false),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickTradeCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> variants;
  const _PickTradeCard({required this.title, required this.variants});
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 480,
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Text('Toca una carta para seleccionarla'),
          Expanded(
            child: variants.isEmpty
                ? const Center(child: Text('Colección vacía'))
                : GridView.extent(
                    padding: const EdgeInsets.all(12),
                    maxCrossAxisExtent: 180,
                    childAspectRatio: .68,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final entry in variants.entries)
                        InkWell(
                          onTap: () => Navigator.pop(context, entry.key),
                          child: _TradeCard(
                            variant: entry.key,
                            label: '${entry.value} copias',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _TradeCard extends StatelessWidget {
  final String variant, label;
  const _TradeCard({required this.variant, required this.label});
  @override
  Widget build(BuildContext context) {
    final parts = variant.split(':');
    final id = int.tryParse(parts.first) ?? -1;
    if (parts.length != 3 || !cardNames.containsKey(id)) {
      return const Text('Carta desconocida');
    }
    if (!CardRarity.values.any((v) => v.name == parts[1]) ||
        !CardFinish.values.any((v) => v.name == parts[2])) {
      return const Text('Variante desconocida');
    }
    final rarity = CardRarity.values.byName(parts[1]),
        finish = CardFinish.values.byName(parts[2]);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          width: 2,
          color: finish == CardFinish.gold
              ? const Color(0xffd7ab49)
              : finish == CardFinish.silver
              ? const Color(0xff9c93c3)
              : const Color(0xffd9dece),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xff477260)),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: cardAsset(id) == null
                  ? Center(
                      child: Text(
                        cardIcons[id],
                        style: const TextStyle(fontSize: 40),
                      ),
                    )
                  : Image.asset(cardAsset(id)!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cardName(id),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '${rarity.label} · ${finish.label}',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
