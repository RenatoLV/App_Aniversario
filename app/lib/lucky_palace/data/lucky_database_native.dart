import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openLuckyDatabase() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(
    '${dir.path}/lucky-palace-local-v1.db',
    version: 1,
    mode: DatabaseMode.create,
  );
}
