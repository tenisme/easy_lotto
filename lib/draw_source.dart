import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DrawSource extends StatelessWidget {
  const DrawSource({
    super.key,
    required this.round,
    required this.status,
    this.open,
  });
  final int? round;
  final String status;
  final Future<bool> Function(Uri)? open;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(round == null ? status : '$round회 기준'),
      const Text(' · '),
      TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        onPressed: () async {
          try {
            final uri = Uri.parse('https://www.dhlottery.co.kr/');
            final success =
                await (open?.call(uri) ??
                    launchUrl(uri, mode: LaunchMode.externalApplication));
            if (!success) throw StateError('브라우저 실행 실패');
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('동행복권 사이트를 열지 못했습니다.')),
              );
            }
          }
        },
        child: const Text(
          '출처 - 동행복권',
          style: TextStyle(decoration: TextDecoration.underline),
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}
