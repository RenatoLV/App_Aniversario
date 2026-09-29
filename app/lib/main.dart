import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'store.dart';
import 'backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.initialize();
  final prefs = await SharedPreferences.getInstance();
  runApp(RinconApp(store: GameStore(prefs)));
}
