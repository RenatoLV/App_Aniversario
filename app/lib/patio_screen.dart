import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'football_screen.dart';
import 'house_day_cycle.dart';
import 'patio_art.dart';
import 'patio_weather.dart';
import 'patio_weather_bar.dart';
import 'store.dart';

class PatioScreen extends StatefulWidget {
  const PatioScreen({super.key, required this.store, this.weather, this.clock});
  final GameStore store;
  final PatioWeather? weather;
  final DateTime Function()? clock;
  @override
  State<PatioScreen> createState() => _PatioScreenState();
}

class _PatioScreenState extends State<PatioScreen>
    with SingleTickerProviderStateMixin {
  late final PatioWeather weather;
  late final AnimationController breeze;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    weather = widget.weather ?? PatioWeather(widget.store.prefs);
    weather.start();
    breeze = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    unawaited(_wakeCats());
  }

  Future<void> _wakeCats() async {
    for (final cat in CatKind.values) {
      if (widget.store.catCare.resting(cat)) {
        await widget.store.catCare.decorateBedroom(
          cat,
          widget.store.catCare.bedroom(cat).copyWith(lamp: true),
        );
      }
    }
  }

  Future<void> _football() async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/goal'),
          builder: (_) => FootballScreen(
            store: widget.store,
            weather: weather,
            clock: widget.clock,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    breeze.dispose();
    if (widget.weather == null) weather.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HouseDayCycle(
    clock: widget.clock,
    builder: (context, light) => Scaffold(
      appBar: AppBar(
        title: const Text('El patio de Maru y Lady'),
        actions: [
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '● ${widget.store.coins}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PatioWeatherBar(weather: weather, light: light),
            LayoutBuilder(
              builder: (context, bounds) {
                final width = bounds.maxWidth,
                    height = (width * 1.04).clamp(330.0, 430.0);
                final catSize = math.min(156.0, width * .42);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([breeze, weather]),
                              builder: (context, _) => CustomPaint(
                                painter: PatioBackdrop(
                                  light: light,
                                  conditions: weather.conditions,
                                  phase: breeze.value,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Un ratito al aire libre',
                              style: TextStyle(
                                color: Color(0xff31594c),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        for (final cat in CatKind.values)
                          Positioned(
                            left: cat == CatKind.maru
                                ? width * .05
                                : width * .53,
                            bottom: cat == CatKind.maru ? 22 : 52,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1100),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) =>
                                  Transform.translate(
                                    offset: Offset(
                                      (1 - t) *
                                          (cat == CatKind.maru ? -55 : 55),
                                      (1 - t) * -65,
                                    ),
                                    child: Opacity(opacity: t, child: child),
                                  ),
                              child: CatActor(
                                cat: cat,
                                size: catSize,
                                showLabel: false,
                                active: true,
                                sleeping: false,
                                movable: true,
                                outfit: widget.store.catCare.outfit(cat),
                                onPet: () => widget.store.catCare.pet(cat),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'A jugar en el pasto',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Card(
              color: const Color(0xffe7f1de),
              child: InkWell(
                key: const ValueKey('patio-football'),
                borderRadius: BorderRadius.circular(16),
                onTap: _football,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sports_soccer_rounded,
                        size: 48,
                        color: Color(0xff45684f),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fútbol de patitas',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Desliza el balón y supera a Maru o Lady.\nCada gol: +30 monedas.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Datos del clima: Open-Meteo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xff6e8071)),
            ),
          ],
        ),
      ),
    ),
  );
}
