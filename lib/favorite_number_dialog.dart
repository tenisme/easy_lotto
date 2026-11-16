import 'word_wrap_text.dart';
import 'package:flutter/material.dart';
import 'number_display.dart';

Future<Set<int>?> pickFavoriteNumbers(BuildContext context, Set<int> saved) =>
    showDialog<Set<int>>(
      context: context,
      builder: (_) => FavoriteNumberDialog(saved: {...saved}),
    );

class FavoriteNumberDialog extends StatefulWidget {
  const FavoriteNumberDialog({super.key, required this.saved});
  final Set<int> saved;
  @override
  State<FavoriteNumberDialog> createState() => _FavoriteNumberDialogState();
}

class _FavoriteNumberDialogState extends State<FavoriteNumberDialog> {
  late final chosen = {...widget.saved};
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 840,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SizedBox(
        width: 840,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: WordWrapText(
                '내 번호 추가·삭제',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: WordWrapText(
                        "터치로 '내 번호'를 추가 및 삭제할 수 있습니다.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    NumberPickerGrid(
                      numbers: List.generate(45, (i) => i + 1),
                      selected: chosen,
                      favorites: chosen,
                      maxColumns:
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape
                          ? 9
                          : 5,
                      onToggle: (n) => setState(() {
                        if (!chosen.add(n)) chosen.remove(n);
                      }),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const WordWrapText(
                        '취소',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {...chosen}),
                      child: const WordWrapText(
                        '확인',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
