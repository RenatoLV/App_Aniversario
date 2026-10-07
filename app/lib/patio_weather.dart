import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum PatioCity {
  coquimbo('Coquimbo', -29.95332, -71.33947),
  laSerena('La Serena', -29.90591, -71.25014);

  const PatioCity(this.label, this.latitude, this.longitude);
  final String label;
  final double latitude, longitude;
}

enum PatioSky { clear, cloudy, fog, rain, snow, storm }

class PatioConditions {
  const PatioConditions(this.code, this.temperature, this.wind, this.fetchedAt);
  final int code;
  final double temperature, wind;
  final DateTime fetchedAt;
  PatioSky get sky => switch (code) {
    1 || 2 || 3 => PatioSky.cloudy,
    45 || 48 => PatioSky.fog,
    >= 71 && <= 77 || 85 || 86 => PatioSky.snow,
    >= 95 => PatioSky.storm,
    >= 51 && <= 67 || >= 80 && <= 82 => PatioSky.rain,
    _ => PatioSky.clear,
  };
  String get label => code == 1
      ? 'Mayormente despejado'
      : code == 2
      ? 'Parcialmente nublado'
      : switch (sky) {
          PatioSky.clear => 'Despejado',
          PatioSky.cloudy => 'Nublado',
          PatioSky.fog => 'Neblina',
          PatioSky.rain => 'Lluvia',
          PatioSky.snow => 'Nieve',
          PatioSky.storm => 'Tormenta',
        };
  Map<String, dynamic> toJson() => {
    'code': code,
    'temperature': temperature,
    'wind': wind,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };
  factory PatioConditions.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as num).toInt();
    final temperature = (json['temperature'] as num).toDouble();
    final wind = (json['wind'] as num).toDouble();
    if (!temperature.isFinite || !wind.isFinite || code < 0 || code > 99) {
      throw const FormatException('Invalid weather values');
    }
    return PatioConditions(
      code,
      temperature,
      wind,
      DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

/// A city choice rather than GPS access; cached weather never blocks play.
class PatioWeather extends ChangeNotifier with WidgetsBindingObserver {
  PatioWeather(this.prefs, {http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now {
    city = PatioCity.values.firstWhere(
      (c) => c.name == prefs.getString('patio.city'),
      orElse: () => PatioCity.coquimbo,
    );
    _loadCache();
  }
  final SharedPreferences prefs;
  final http.Client _client;
  final DateTime Function() _clock;
  late PatioCity city;
  PatioConditions? conditions;
  bool busy = false, offline = false, _closed = false, _started = false;
  int _generation = 0;
  Timer? _timer;
  bool get cached =>
      offline ||
      (conditions != null &&
          _clock().difference(conditions!.fetchedAt) >
              const Duration(minutes: 30));

  void _loadCache() {
    conditions = null;
    try {
      final raw = prefs.getString('patio.weather.${city.name}');
      if (raw != null) conditions = PatioConditions.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    unawaited(refresh());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(refresh()),
    );
  }

  Future<void> setCity(PatioCity next) async {
    if (city == next) return;
    _generation++;
    city = next;
    busy = false;
    offline = false;
    _loadCache();
    notifyListeners();
    await prefs.setString('patio.city', next.name);
    if (!_closed) await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (_closed || busy) return;
    if (!force &&
        conditions != null &&
        !offline &&
        _clock().difference(conditions!.fetchedAt) <
            const Duration(minutes: 15)) {
      return;
    }
    busy = true;
    notifyListeners();
    final generation = ++_generation, target = city;
    try {
      final response = await _client
          .get(
            Uri.https('api.open-meteo.com', '/v1/forecast', {
              'latitude': '${target.latitude}',
              'longitude': '${target.longitude}',
              'current': 'temperature_2m,weather_code,wind_speed_10m',
              'timezone': 'America/Santiago',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Weather unavailable');
      }
      final current =
          (jsonDecode(response.body) as Map<String, dynamic>)['current']
              as Map<String, dynamic>;
      final next = PatioConditions.fromJson({
        'code': current['weather_code'],
        'temperature': current['temperature_2m'],
        'wind': current['wind_speed_10m'],
        'fetchedAt': _clock().toUtc().toIso8601String(),
      });
      if (_closed || generation != _generation) return;
      conditions = next;
      offline = false;
      await prefs.setString(
        'patio.weather.${target.name}',
        jsonEncode(next.toJson()),
      );
    } catch (_) {
      if (!_closed && generation == _generation) offline = true;
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      unawaited(refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }
}
