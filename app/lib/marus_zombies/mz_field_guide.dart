import 'package:flutter/material.dart';
import 'mz_catalog.dart';
import 'mz_levels.dart';

/// Optional help inside existing preparation/pause surfaces. No extra modal,
/// combat timer, progression flag or reward is introduced.
class MzFieldGuide extends StatelessWidget {
  const MzFieldGuide({
    super.key,
    required this.level,
    this.initiallyExpanded = false,
  });
  final MzLevel level;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    tilePadding: EdgeInsets.zero,
    title: const Text(
      'Cómo jugar',
      style: TextStyle(fontWeight: FontWeight.w900),
    ),
    subtitle: const Text('Ayuda opcional · toca para abrir o cerrar'),
    children: [
      for (final text in [
        if (level.id == 0)
          'Empiezas con tres carriles y el Lanzador. Protege la casa a la izquierda.',
        'Toca una carta y una casilla libre, o arrástrala al jardín. En pantallas pequeñas, confirma la casilla.',
        'Toca la hierba para recoger 25. El coste se paga al colocar; el contador de la carta indica su recarga. Desactiva las herramientas para recoger recursos.',
        'Pala: retira un gato sin devolver su coste. Atún: recoge una lata y toca un gato para su poder; Gatitos bomba explota solo. En pantallas pequeñas, confirma antes de usarlo.',
        'Conos y baldes absorben daño. Cada Roomba despeja su carril una vez. Pierdes si llega un invasor por un carril que ya gastó su Roomba; vence a toda la horda para ganar.',
        level.world.rule,
        switch (level.world) {
          MzWorld.cemetery =>
            'Las lápidas bloquean casillas y ovillos. La Catapulta puede disparar por encima. Bumerán ya está disponible al terminar Patio.',
          MzWorld.egypt =>
            'El Faraón tiene protección. El Ladrón, desde la quinta misión de Egipto, roba hierba que aún no recogiste.',
          MzWorld.pirates =>
            'El Corsario puede aterrizar dentro del jardín; el Loro puede llevarse gatos. Resorte empuja al contacto, pero no mueve al jefe.',
          MzWorld.west =>
            'Selecciona Carrito, toca un carro en la columna de vías y después su nueva fila libre. Vigila al Minero que aparece detrás.',
          MzWorld.future =>
            'Los nodos comparten el atún entre gatos del mismo símbolo. Láser atraviesa la protección. El jefe llega en la última misión.',
          MzWorld.patio =>
            'Conserva tus Roombas y cumple el objetivo de la misión para ganar más estrellas. Las recompensas nuevas se guardan al terminar.',
        },
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(alignment: Alignment.centerLeft, child: Text(text)),
        ),
    ],
  );
}
