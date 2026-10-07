import 'dart:async';
import 'package:flutter/material.dart';
import 'house_day_cycle.dart';
import 'patio_weather.dart';

class PatioWeatherBar extends StatelessWidget {
  const PatioWeatherBar({
    super.key,
    required this.weather,
    required this.light,
  });
  final PatioWeather weather;
  final HouseLight light;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: weather,
    builder: (context, _) {
      final data = weather.conditions;
      final text = data == null
          ? (weather.busy ? 'Buscando clima…' : 'Clima no disponible')
          : '${data.label} · ${data.temperature.round()} °C${weather.cached ? ' · guardado' : ''}';
      return Row(
        children: [
          PopupMenuButton<PatioCity>(
            key: const ValueKey('patio-city'),
            tooltip: 'Cambiar ciudad del clima',
            initialValue: weather.city,
            onSelected: (city) => unawaited(weather.setCity(city)),
            itemBuilder: (_) => [
              for (final city in PatioCity.values)
                PopupMenuItem(value: city, child: Text(city.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 3),
                  Text(
                    weather.city.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${light.label} · $text',
              maxLines: 2,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            tooltip: 'Acerca del clima',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Clima del patio'),
                content: Text(
                  'Datos meteorológicos: Open-Meteo (open-meteo.com).\n\n'
                  'Se consulta la ciudad elegida cada 15 minutos, sin usar tu ubicación GPS. '
                  'El patio refleja la hora de tu teléfono.\n\n'
                  '${data == null ? 'No hay datos guardados. Puedes jugar sin conexión.' : 'Última consulta: ${data.fetchedAt.toLocal().hour.toString().padLeft(2, '0')}:${data.fetchedAt.toLocal().minute.toString().padLeft(2, '0')}. Si falla la conexión, se conserva ese clima y se indica como guardado.'}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
