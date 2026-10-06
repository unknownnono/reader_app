import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reader_settings.dart';
import '../../providers.dart';

/// 여러 선택지 가운데 하나를 고르는 아이폰식 막대
class SegmentedSetting<T extends Object> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;

  /// null이면 고를 수 없는 상태로 흐리게 보여 준다.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<T>(
            groupValue: selected,
            onValueChanged: (value) {
              if (value != null) onChanged?.call(value);
            },
            children: {
              for (final value in values)
                value: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(labelOf(value), style: const TextStyle(fontSize: 14)),
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// 이름, 지금 값, 줄이기·늘리기 버튼으로 된 한 줄
class StepperSetting extends StatelessWidget {
  const StepperSetting({
    super.key,
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
          icon: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(width: 36, child: Text(value, textAlign: TextAlign.center)),
        IconButton(
          tooltip: '$label 늘리기',
          onPressed: onPlus,
          icon: const Icon(CupertinoIcons.plus_circle),
        ),
      ],
    );
  }
}

/// 설정 항목의 작은 제목
class SettingLabel extends StatelessWidget {
  const SettingLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// 읽는 동안의 화면 밝기. 오른쪽 버튼으로 기기 밝기를 그대로 쓰도록 되돌린다.
class BrightnessControl extends ConsumerWidget {
  const BrightnessControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(readerSettingsProvider.select((s) => s.brightness));
    final notifier = ref.read(readerSettingsProvider.notifier);
    final usesSystem = brightness < 0;
    return Row(
      children: [
        const Icon(CupertinoIcons.sun_min, size: 20),
        Expanded(
          child: Slider.adaptive(
            // 기기 밝기를 쓰는 동안에는 손잡이를 가운데에 둔다.
            value: usesSystem ? 0.5 : brightness,
            min: ReaderSettings.minBrightness,
            onChanged: (value) => notifier.update((s) => s.copyWith(brightness: value)),
          ),
        ),
        const Icon(CupertinoIcons.sun_max, size: 22),
        TextButton(
          onPressed: usesSystem
              ? null
              : () => notifier.update(
                    (s) => s.copyWith(brightness: ReaderSettings.systemBrightness),
                  ),
          child: Text(usesSystem ? '기기 밝기' : '되돌리기'),
        ),
      ],
    );
  }
}

/// 글 읽기 설정 묶음. 읽기 화면의 설정 창과 설정 탭이 함께 쓴다.
class TextReadingControls extends ConsumerWidget {
  const TextReadingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingLabel('배경'),
        SegmentedSetting<ReaderTheme>(
          values: ReaderTheme.values,
          labelOf: (theme) => theme.label,
          selected: settings.theme,
          onChanged: (theme) => notifier.update((s) => s.copyWith(theme: theme)),
        ),
        const SizedBox(height: 8),
        const BrightnessControl(),
        StepperSetting(
          label: '글자 크기',
          value: settings.fontSize.round().toString(),
          onMinus: settings.fontSize > ReaderSettings.minFontSize
              ? () => notifier.update((s) => s.copyWith(fontSize: s.fontSize - 1))
              : null,
          onPlus: settings.fontSize < ReaderSettings.maxFontSize
              ? () => notifier.update((s) => s.copyWith(fontSize: s.fontSize + 1))
              : null,
        ),
        StepperSetting(
          label: '줄 간격',
          value: settings.lineHeight.toStringAsFixed(1),
          onMinus: settings.lineHeight > ReaderSettings.minLineHeight + 0.01
              ? () => notifier.update((s) => s.copyWith(lineHeight: s.lineHeight - 0.1))
              : null,
          onPlus: settings.lineHeight < ReaderSettings.maxLineHeight - 0.01
              ? () => notifier.update((s) => s.copyWith(lineHeight: s.lineHeight + 0.1))
              : null,
        ),
        StepperSetting(
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
    );
  }
}

/// 만화 보기 설정 묶음. 만화 뷰어의 설정 창과 설정 탭이 함께 쓴다.
class ComicReadingControls extends ConsumerWidget {
  const ComicReadingControls({super.key, this.showBrightness = true});

  /// 설정 탭에서는 글 읽기 묶음에 밝기가 이미 있어 여기서는 뺀다.
  final bool showBrightness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final paged = settings.comicMode == ComicMode.paged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingLabel('보기 방식'),
        SegmentedSetting<ComicMode>(
          values: ComicMode.values,
          labelOf: (mode) => mode.label,
          selected: settings.comicMode,
          onChanged: (mode) => notifier.update((s) => s.copyWith(comicMode: mode)),
        ),
        const SettingLabel('넘기는 방향'),
        SegmentedSetting<bool>(
          values: const [false, true],
          labelOf: (rightToLeft) => rightToLeft ? '오른쪽 → 왼쪽' : '왼쪽 → 오른쪽',
          selected: settings.comicRightToLeft,
          // 세로 스크롤에는 좌우 방향이 없다.
          onChanged: paged
              ? (value) => notifier.update((s) => s.copyWith(comicRightToLeft: value))
              : null,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(child: Text('가로 화면에서 두 쪽 보기')),
            Switch.adaptive(
              value: settings.comicDoublePage,
              onChanged: paged
                  ? (value) => notifier.update((s) => s.copyWith(comicDoublePage: value))
                  : null,
            ),
          ],
        ),
        if (showBrightness) const BrightnessControl(),
      ],
    );
  }
}
