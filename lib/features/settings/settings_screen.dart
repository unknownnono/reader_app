import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../providers.dart';
import '../transfer/transfer_screen.dart';
import 'diag_screen.dart';
import 'settings_controls.dart';

/// 설정 탭. 아이폰 설정 앱처럼 묶음 단위로 나눈다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    void open(Widget screen) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => screen),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerLow,
        centerTitle: false,
        titleSpacing: 20,
        title: const LargeTitle('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _Section(
            title: '글 읽기',
            footer: 'txt와 epub에 적용됩니다. 읽는 화면에서도 바꿀 수 있습니다.',
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: TextReadingControls(),
            ),
          ),
          const _Section(
            title: '만화',
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: ComicReadingControls(showBrightness: false),
            ),
          ),
          _Section(
            title: '파일',
            footer: '"짱 01, 짱 02…"처럼 권 번호만 다른 책을 한 칸으로 묶어 보여 줍니다.',
            child: _Row(
              label: '시리즈로 묶기',
              trailing: Switch.adaptive(
                value: settings.groupSeries,
                onChanged: (value) => notifier.update((s) => s.copyWith(groupSeries: value)),
              ),
            ),
          ),
          _Section(
            title: '책 넣기',
            footer: '파일 앱의 나의 iPhone → $appName 폴더에 넣은 파일과 폴더도 자동으로 들어옵니다.',
            child: _Row(
              label: 'Wi-Fi로 받기',
              trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
              onTap: () => open(const TransferScreen()),
            ),
          ),
          _Section(
            title: '도움',
            child: _Row(
              label: '진단 기록',
              trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
              onTap: () => open(const DiagScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 둥근 판 하나와 그 위아래의 작은 글
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.footer});

  final String title;
  final Widget child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(title, style: small),
        ),
        Material(
          // 어두운 화면에서는 바탕보다 한 단계 밝은 판, 밝은 화면에서는 흰 판
          color: scheme.brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(footer!, style: small),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(label),
              ),
            ),
            IconTheme.merge(
              data: IconThemeData(color: Theme.of(context).colorScheme.onSurfaceVariant),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}
