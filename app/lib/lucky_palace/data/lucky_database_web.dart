import 'package:sembast_web/sembast_web.dart';

Future<Database> openLuckyDatabase() => databaseFactoryWeb.openDatabase(
  'lucky-palace-local-v1',
  version: 1,
  mode: DatabaseMode.create,
);
