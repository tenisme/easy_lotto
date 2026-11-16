import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/local_storage.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  LocalStorage.factory = databaseFactoryFfiNoIsolate;
  LocalStorage.pathOverride = inMemoryDatabasePath;
  setUp(() async {
    await LocalStorage.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async => LocalStorage.reset());
  await testMain();
}
