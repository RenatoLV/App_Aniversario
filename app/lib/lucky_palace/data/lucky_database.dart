import 'package:sembast/sembast.dart';
import 'lucky_database_native.dart'
    if (dart.library.js_interop) 'lucky_database_web.dart'
    as platform;
import 'lucky_models.dart';

Future<Database> openLuckyDatabase() => platform.openLuckyDatabase();
const luckyDatabaseVersion = 1;
final luckyRecords = stringMapStoreFactory.store('lucky.v1');

/// No GameStore/ProgressSync keys. A failed disk commit poisons this handle until
/// reopened, so an in-memory database cache is never advertised as confirmed.
class LuckyDatabase {
  LuckyDatabase(this.db, {this.beforeCommit});
  final Database db;
  final Future<void> Function()? beforeCommit;
  bool _failed = false;
  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    if (_failed) {
      throw StateError(
        'Reabre el almacenamiento; no se confirmó la escritura anterior',
      );
    }
    try {
      return await db.transaction((tx) async {
        final result = await action(tx);
        await beforeCommit?.call();
        return result;
      });
    } catch (error) {
      // Business rejections do not poison an otherwise intact database.
      if (error is! StateError && error is! LuckyDeclined) {
        _failed = true;
        try {
          await db.close();
        } catch (_) {
          /* Preserve file; do not reset. */
        }
      }
      rethrow;
    }
  }
}
