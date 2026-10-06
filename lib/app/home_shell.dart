import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/library_screen.dart';
import '../features/recent/recent_screen.dart';
import '../features/settings/settings_screen.dart';
import '../providers.dart';

const _recentTab = 0;
const _filesTab = 1;

/// 앱의 첫 화면. 아래쪽 탭으로 최근·파일·설정을 오간다.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// 고른 탭. 아직 고르지 않았으면 null이고, 서재를 읽은 뒤 알맞은 탭으로 정한다.
  int? _tab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 읽던 책이 있으면 최근 탭에서, 처음이면 책을 넣을 수 있는 파일 탭에서 시작한다.
    final books = ref.watch(booksProvider);
    if (_tab == null && books.hasValue) {
      _tab = ref.read(recentBooksProvider).isEmpty ? _filesTab : _recentTab;
    }
    final tab = _tab ?? _filesTab;

    return Scaffold(
      // 탭을 오가도 스크롤 위치와 검색 상태가 남도록 모두 살려 둔다.
      body: IndexedStack(
        index: tab,
        children: [
          RecentScreen(onOpenFiles: () => setState(() => _tab = _filesTab)),
          const LibraryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: tab,
        onTap: (index) => setState(() => _tab = index),
        backgroundColor: scheme.surface.withValues(alpha: 0.94),
        activeColor: scheme.primary,
        inactiveColor: scheme.onSurfaceVariant,
        border: Border(top: BorderSide(color: scheme.outline, width: 0.5)),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.clock), label: '최근'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.folder), label: '파일'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: '설정'),
        ],
      ),
    );
  }
}
