import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_lotto/draw_store.dart';

void main() {
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
