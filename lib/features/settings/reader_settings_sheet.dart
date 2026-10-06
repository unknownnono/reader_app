import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reader_settings.dart';
import '../../providers.dart';
import '../reader/reading_session.dart';

/// 글 읽기 화면에서 여는 설정 창. 바꾸는 즉시 뒤의 본문에 반영된다.
void showReaderSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    // 뒤의 본문이 바뀌는 모습이 보이도록 어둡게 덮지 않는다.
    barrierColor: Colors.transparent,
    builder: (_) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('배경'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final theme in ReaderTheme.values)
                  ChoiceChip(
                    label: Text(theme.label),
                    selected: settings.theme == theme,
                    onSelected: (_) => notifier.update((s) => s.copyWith(theme: theme)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const BrightnessControl(),
            _Stepper(
              label: '글자 크기',
              value: settings.fontSize.round().toString(),
              onMinus: settings.fontSize > ReaderSettings.minFontSize
                  ? () => notifier.update((s) => s.copyWith(fontSize: s.fontSize - 1))
                  : null,
              onPlus: settings.fontSize < ReaderSettings.maxFontSize
                  ? () => notifier.update((s) => s.copyWith(fontSize: s.fontSize + 1))
                  : null,
            ),
            _Stepper(
              label: '줄 간격',
              value: settings.lineHeight.toStringAsFixed(1),
              onMinus: settings.lineHeight > ReaderSettings.minLineHeight + 0.01
                  ? () => notifier.update((s) => s.copyWith(lineHeight: s.lineHeight - 0.1))
                  : null,
              onPlus: settings.lineHeight < ReaderSettings.maxLineHeight - 0.01
                  ? () => notifier.update((s) => s.copyWith(lineHeight: s.lineHeight + 0.1))
                  : null,
            ),
            _Stepper(
              label: '좌우 여백',
              value: settings.margin.round().toString(),
              onMinus: settings.margin > ReaderSettings.minMargin
                  ? () => notifier.update((s) => s.copyWith(margin: s.margin - 4))
                  : null,
              onPlus: settings.margin < ReaderSettings.maxMargin
                  ? () => notifier.update((s) => s.copyWith(margin: s.margin + 4))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '$label 줄이기',
          onPressed: onMinus,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 40, child: Text(value, textAlign: TextAlign.center)),
        IconButton(
          tooltip: '$label 늘리기',
          onPressed: onPlus,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
