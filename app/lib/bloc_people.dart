import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'backend.dart';

class BlocPeople {
  static CollectionReference<Map<String, dynamic>> get directory =>
      Backend.db.collection('user_directory');
  static CollectionReference<Map<String, dynamic>> get requests =>
      Backend.db.collection('bloc_requests');
  static Future<void> publish(String name) async {
    if (Backend.uid == null) return;
    await directory.doc(Backend.uid).set({
      'name': name,
      'nameKey': name.toLowerCase().trim(),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> people(String prefix) {
    var query = directory.orderBy('nameKey');
    final key = prefix.toLowerCase().trim();
    if (key.isNotEmpty) query = query.startAt([key]).endAt(['$key\uf8ff']);
    return query.limit(30).snapshots();
  }

  static Future<void> request(String target) async {
    if (target == Backend.uid || Backend.uid == null) return;
    final member = await Backend.membership();
    final id = '${target}_${Backend.uid}';
    final previous = await requests
        .where('fromUid', isEqualTo: Backend.uid)
        .get();
    final existing = previous.docs.where((d) => d.id == id);
    if (existing.isNotEmpty) {
      if (existing.first.data()['status'] != 'rejected') return;
      await requests.doc(id).update({
        'status': 'pending',
        'spaceId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await requests.doc(id).set({
      'fromUid': Backend.uid,
      'toUid': target,
      'name': member?['nickname'] ?? 'Jugador',
      'status': 'pending',
      'spaceId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> inbox() =>
      requests.where('toUid', isEqualTo: Backend.uid).snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> sent() =>
      requests.where('fromUid', isEqualTo: Backend.uid).snapshots();
  static Future<void> respond(String id, bool accept) async {
    String? room;
    if (accept) {
      room = Backend.space;
      if (room == null ||
          (await Backend.db.collection('spaces').doc(room).get())
                  .data()?['owner'] !=
              Backend.uid) {
        throw StateError(
          'Solo el dueño puede aceptar solicitudes para este bloc.',
        );
      }
    }
    await requests.doc(id).update({
      'status': accept ? 'accepted' : 'rejected',
      'spaceId': room,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class BlocPeopleSheet extends StatefulWidget {
  final Future<void> Function() onCode;
  const BlocPeopleSheet({super.key, required this.onCode});
  @override
  State<BlocPeopleSheet> createState() => _BlocPeopleSheetState();
}

class _BlocPeopleSheetState extends State<BlocPeopleSheet> {
  String search = '', message = '';
  bool busy = false;
  Future<void> act(Future<void> Function() task, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (mounted) setState(() => message = success);
    } catch (e) {
      if (mounted) setState(() => message = Backend.loginErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .83,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Compartir nuestro bloc',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Busca por nombre. Envía una solicitud y entra cuando el dueño la acepte.',
                textAlign: TextAlign.center,
              ),
            ),
            if (message.isNotEmpty)
              Padding(padding: const EdgeInsets.all(10), child: Text(message)),
            const TabBar(
              tabs: [
                Tab(text: 'Personas'),
                Tab(text: 'Recibidas'),
                Tab(text: 'Enviadas'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Nombre en la app',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (s) => setState(() => search = s),
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: BlocPeople.people(search),
                          builder: (context, s) {
                            if (s.hasError) {
                              return const Center(
                                child: Text(
                                  'No se pudo buscar. Revisa tu conexión.',
                                ),
                              );
                            }
                            if (!s.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final rows = s.data!.docs
                                .where((d) => d.id != Backend.uid)
                                .toList();
                            if (rows.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No encontramos usuarios con ese nombre.',
                                ),
                              );
                            }
                            return ListView(
                              children: [
                                for (final d in rows)
                                  ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(d.data()['name'] as String),
                                    subtitle: Text(
                                      '#${d.id.substring(0, 6)} · Usuario de la app',
                                    ),
                                    trailing: TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => act(
                                              () => BlocPeople.request(d.id),
                                              'Solicitud enviada',
                                            ),
                                      child: const Text('Solicitar'),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _requests(incoming: true),
                  _requests(incoming: false),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : widget.onCode,
              icon: const Icon(Icons.key_outlined),
              label: const Text('También puedes usar un código de invitación'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _requests({
    required bool incoming,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: incoming ? BlocPeople.inbox() : BlocPeople.sent(),
    builder: (context, s) {
      if (s.hasError) {
        return const Center(
          child: Text('No se pudieron cargar las solicitudes.'),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = s.data!.docs;
      if (rows.isEmpty) {
        return const Center(child: Text('Todavía no hay solicitudes'));
      }
      return ListView(
        children: [
          for (final d in rows)
            Builder(
              builder: (context) {
                final data = d.data(), status = data['status'];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (incoming)
                          Text('${data['name']} quiere unirse a tu bloc')
                        else
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: BlocPeople.directory
                                .doc(data['toUid'] as String)
                                .snapshots(),
                            builder: (context, profile) => Text(
                              'Solicitud a ${profile.data?.data()?['name'] ?? 'otro usuario'}',
                            ),
                          ),
                        Text(
                          status == 'pending'
                              ? 'Pendiente'
                              : status == 'accepted'
                              ? 'Aceptada'
                              : 'Rechazada',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (incoming && status == 'pending')
                          Row(
                            children: [
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => act(
                                        () => BlocPeople.respond(d.id, false),
                                        'Solicitud rechazada',
                                      ),
                                child: const Text('Rechazar'),
                              ),
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => act(
                                        () => BlocPeople.respond(d.id, true),
                                        'Acceso concedido',
                                      ),
                                child: const Text('Aceptar'),
                              ),
                            ],
                          ),
                        if (!incoming && status == 'accepted')
                          FilledButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Entrar a su bloc'),
                            onPressed: busy
                                ? null
                                : () async {
                                    await act(
                                      () => Backend.joinSpace(
                                        data['spaceId'] as String,
                                      ),
                                      '',
                                    );
                                    if (context.mounted && message.isEmpty) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
