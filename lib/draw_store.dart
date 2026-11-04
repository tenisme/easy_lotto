import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/recommendation.dart';

DrawResult? parseDraw(String body, int round) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  final list = (data['data'] as Map<String, dynamic>)['list'] as List;
  if (list.isEmpty) return null;
  final row = list.single as Map<String, dynamic>;
  if (row['ltEpsd'] != round) throw const FormatException('회차 불일치');
  return DrawResult(
    round,
    LottoGame([for (var i = 1; i <= 6; i++) row['tm${i}WnNo'] as int]),
    row['bnsWnNo'] as int,
  );
}

class DrawStore {
  final List<DrawResult> draws = [];
  String status = '추첨 데이터를 확인하고 있습니다.';
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('draws.v1') ?? [];
      final restored = <DrawResult>[];
      for (final item in saved) {
        final row = jsonDecode(item) as Map<String, dynamic>;
        restored.add(
          DrawResult(
            row['round'] as int,
            LottoGame((row['numbers'] as List).cast<int>()),
            row['bonus'] as int,
          ),
        );
      }
      draws
        ..clear()
        ..addAll(restored);
      draws.sort((a, b) => b.round.compareTo(a.round));
      final now = DateTime.now().toUtc();
      // First draw Saturday; wait until Sunday 00:00 KST for publishing.
      final week = now.difference(DateTime.utc(2002, 12, 7, 15)).inDays ~/ 7;
      if (prefs.getInt('drawCheckWeek.v1') != week) {
        // Record attempt first to avoid repeated calls on server failures.
        await prefs.setInt('drawCheckWeek.v1', week);
        final latest = week + 1;
        final updated = <DrawResult>[];
        for (var round = latest; round > latest - 5 && round > 0; round--) {
          final existing = draws.where((d) => d.round == round);
          if (existing.isNotEmpty) {
            updated.add(existing.first);
            continue;
          }
          final response = await http
              .get(
                Uri.https(
                  'www.dhlottery.co.kr',
                  '/lt645/selectPstLt645Info.do',
                  {'srchDir': 'center', 'srchLtEpsd': '$round'},
                ),
              )
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) throw const FormatException('조회 실패');
          final draw = parseDraw(response.body, round);
          if (draw != null) updated.add(draw);
        }
        final merged = {
          for (final d in draws) d.round: d,
          for (final d in updated) d.round: d,
        };
        final next = merged.values.toList()
          ..sort((a, b) => b.round.compareTo(a.round));
        await prefs.setStringList(
          'draws.v1',
          next
              .map(
                (d) => jsonEncode({
                  'round': d.round,
                  'numbers': d.main.numbers,
                  'bonus': d.bonus,
                }),
              )
              .toList(),
        );
        draws
          ..clear()
          ..addAll(next);
      }
      status = draws.isEmpty
          ? '아직 추첨 데이터가 없습니다.'
          : '${draws.first.round}회 기준 · ${draws.length}회 저장';
    } catch (_) {
      status = draws.isEmpty
          ? '데이터 조회에 실패했습니다.'
          : '${draws.first.round}회 기준 · 마지막 저장 데이터 사용';
    }
  }
}
