import 'package:flutter/material.dart';
import 'display_preferences.dart';
import 'word_wrap_text.dart';

enum StyleResetArea { background, numbers, all }

class StyleResetDialog extends StatefulWidget {
  const StyleResetDialog({
    super.key,
    required this.paperId,
    this.onResetNumbers,
  });
  final String paperId;
  final ValueChanged<bool>? onResetNumbers;
  @override
  State<StyleResetDialog> createState() => _StyleResetDialogState();
}

class _StyleResetDialogState extends State<StyleResetDialog> {
  StyleResetArea area = StyleResetArea.numbers;
  bool all = false, busy = false;
  Future<void> reset() async {
    final numbers = area != StyleResetArea.background,
        background = area != StyleResetArea.numbers;
    final subject = all ? '모든 용지' : '이 용지';
    final message = [
      if (background) '$subject의 배경 이미지 설정이 초기화됩니다.',
      if (numbers)
        all
            ? '기본 디자인과 모든 용지별 번호 칸 디자인 설정이 초기화되며, 컬러 기본 디자인으로 복원됩니다.'
            : '이 용지의 개별 번호 칸 디자인 설정이 초기화되며, 현재 기본 디자인을 따릅니다.',
      '저장된 번호와 용지 내용은 유지됩니다.',
      '이 작업은 되돌릴 수 없습니다. 실행하시겠습니까?',
    ].join('\n');
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스타일을 초기화하시겠습니까?'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const WordWrapText('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const WordWrapText('초기화'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final current = await DisplayPreferences.load();
      final next = current.reset(
        paperId: widget.paperId,
        all: all,
        numbers: numbers,
        background: background,
      );
      await next.save();
      if (mounted) {
        widget.onResetNumbers?.call(numbers);
        Navigator.pop(context, next);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('스타일을 초기화하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('스타일 초기화'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '초기화 영역',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioGroup<StyleResetArea>(
              groupValue: area,
              onChanged: (v) {
                if (!busy) setState(() => area = v!);
              },
              child: Column(
                children: [
                  for (final value in StyleResetArea.values)
                    RadioListTile<StyleResetArea>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      title: Text(
                        ['배경 이미지 초기화', '번호 칸 디자인 초기화', '전부 초기화'][value.index],
                      ),
                    ),
                ],
              ),
            ),
            if (area != StyleResetArea.numbers)
              const Text(
                '배경 이미지 변경은 업데이트 예정입니다. 저장된 배경 설정이 없으면 해당 영역은 변경되지 않습니다.',
              ),
            const SizedBox(height: 16),
            const Text(
              '초기화 범위',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioGroup<bool>(
              groupValue: all,
              onChanged: (v) {
                if (!busy) setState(() => all = v!);
              },
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    title: Text('개별 용지 초기화'),
                  ),
                  RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    title: Text('모든 용지 초기화'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const WordWrapText('취소'),
      ),
      FilledButton(
        onPressed: busy ? null : reset,
        child: WordWrapText(busy ? '초기화 중입니다' : '초기화'),
      ),
    ],
  );
}
