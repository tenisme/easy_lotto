import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_lotto/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/draw_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final snapshot = File('assets/draws.json').readAsStringSync();
  test('bundled history is complete and supports latest 100 draws', () {
    final draws = parseSnapshot(snapshot);
    expect(draws.length, 1248);
    expect(draws.first.round, 1248);
    expect(draws.last.round, 1);
    expect(draws.take(100).last.round, 1149);
  });
  test('first offline launch persists full bundle', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DrawStore(
      snapshot: () async => snapshot,
      now: () => DateTime.utc(2026, 11, 4),
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    await store.load();
    expect(store.draws.length, 1248);
    expect(
      (await LocalStorage.getInstance()).getStringList('draws.v1')!.length,
      1248,
    );
  });
  test(
    'only new rounds are requested and repeat launches respect weekly limit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requested = <int>[];
      final client = MockClient((request) async {
        final round = int.parse(request.url.queryParameters['srchLtEpsd']!);
        requested.add(round);
        return http.Response(
          jsonEncode({
            'data': {
              'list': [
                {
                  'ltEpsd': round,
                  for (var n = 1; n <= 6; n++) 'tm${n}WnNo': n,
                  'bnsWnNo': 7,
                },
              ],
            },
          }),
          200,
        );
      });
      final store = DrawStore(
        snapshot: () async => snapshot,
        client: client,
        now: () =>
            DateTime.utc(2002, 12, 7, 15).add(const Duration(days: 1249 * 7)),
      );
      await store.load();
      await store.load();
      expect(requested, [1249, 1250]);
      expect(store.draws.first.round, 1250);
      expect(store.draws.length, 1250);
    },
  );
  test(
    'empty future response and server errors preserve initial history',
    () async {
      for (final body in ['{"data":{"list":[]}}', '<html>Error</html>']) {
        SharedPreferences.setMockInitialValues({});
        final store = DrawStore(
          snapshot: () async => snapshot,
          now: () =>
              DateTime.utc(2002, 12, 7, 15).add(const Duration(days: 1248 * 7)),
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await store.load();
        expect(store.draws.length, 1248);
        expect(store.draws.first.round, 1248);
      }
    },
  );
  test('corrupt cache recovers from bundle', () async {
    SharedPreferences.setMockInitialValues({
      'draws.v1': ['broken'],
    });
    final store = DrawStore(
      snapshot: () async => snapshot,
      now: () => DateTime.utc(2026, 11, 4),
    );
    await store.load();
    expect(store.draws.length, 1248);
  });
  String response(Map<String, Object> row) => jsonEncode({
    'data': {
      'list': [row],
    },
  });
  final row = <String, Object>{
    'ltEpsd': 5,
    'tm1WnNo': 16,
    'tm2WnNo': 24,
    'tm3WnNo': 29,
    'tm4WnNo': 40,
    'tm5WnNo': 41,
    'tm6WnNo': 42,
    'bnsWnNo': 3,
  };
  test('parses official six numbers and bonus', () {
    final draw = parseDraw(response(row), 5)!;
    expect(draw.main.numbers, [16, 24, 29, 40, 41, 42]);
    expect(draw.bonus, 3);
  });
  test('empty list means unpublished; HTML is not empty data', () {
    expect(parseDraw('{"data":{"list":[]}}', 5), isNull);
    expect(() => parseDraw('<html>Error</html>', 5), throwsFormatException);
  });
  test('wrong round and invalid numbers are rejected', () {
    expect(() => parseDraw(response(row), 6), throwsFormatException);
    expect(
      () => parseDraw(response({...row, 'bnsWnNo': 16}), 5),
      throwsArgumentError,
    );
  });
}
