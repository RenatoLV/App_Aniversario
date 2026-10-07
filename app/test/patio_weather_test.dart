import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/patio_weather.dart';

http.Response response(int code) => http.Response(
  jsonEncode({
    'current': {
      'weather_code': code,
      'temperature_2m': 17.2,
      'wind_speed_10m': 9.1,
    },
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'City weather is cached, throttled, and preserved transparently while offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var time = DateTime(2026, 10, 7, 12), calls = 0;
      var fail = false;
      final weather = PatioWeather(
        prefs,
        clock: () => time,
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['latitude'], '-29.95332');
          return fail ? http.Response('', 503) : response(45);
        }),
      );
      await weather.refresh();
      expect(weather.conditions!.sky, PatioSky.fog);
      await weather.refresh();
      expect(calls, 1);
      time = time.add(const Duration(minutes: 16));
      fail = true;
      await weather.refresh();
      expect(weather.offline, isTrue);
      expect(weather.cached, isTrue);
      expect(weather.conditions!.code, 45);
      final restored = PatioWeather(prefs, clock: () => time);
      expect(restored.conditions!.code, 45);
      weather.dispose();
      restored.dispose();
    },
  );
  test(
    'A delayed Coquimbo request cannot replace the newly selected La Serena climate',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Completer<http.Response>();
      final weather = PatioWeather(
        prefs,
        client: MockClient((request) async {
          if (request.url.queryParameters['latitude'] == '-29.95332') {
            return first.future;
          }
          expect(request.url.queryParameters['latitude'], '-29.90591');
          return response(61);
        }),
      );
      final pending = weather.refresh();
      await weather.setCity(PatioCity.laSerena);
      first.complete(response(0));
      await pending;
      expect(weather.city, PatioCity.laSerena);
      expect(weather.conditions!.sky, PatioSky.rain);
      expect(weather.busy, isFalse);
      expect(prefs.getString('patio.city'), 'laSerena');
      weather.dispose();
    },
  );
}
