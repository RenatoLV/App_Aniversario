import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'store.dart';
import 'backend.dart';
import 'game_audio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.initialize();
  final prefs = await SharedPreferences.getInstance();
  await GameAudio.instance.initialize(prefs);
  runApp(RinconApp(store: GameStore(prefs)));
}
