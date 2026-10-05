import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../core/diag/diag_log.dart';
import '../../data/db/app_database.dart';
import '../../domain/reader_settings.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';
import '../settings/diag_screen.dart';
import 'book_cover.dart';
import 'import/book_importer.dart';

/// 앱 문서 폴더가 파일 앱에 보이는 플랫폼에서만 "앱 폴더에서 가져오기"를 쓴다.
/// 디버그 빌드에서는 에뮬레이터로 확인할 수 있게 Android에서도 켠다.
bool get _usesAppFolder => Platform.isIOS || kDebugMode;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final AppLifecycleListener _lifecycle;

  /// 선택한 책의 id. 비어 있지 않으면 선택 모드다.
  final _selected = <int>{};
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // 파일 앱에서 책을 넣고 돌아오면 바로 서재에 나타나게 한다.
    _lifecycle = AppLifecycleListener(onResume: () => _scanAppFolder(silent: true));
    _scanAppFolder(silent: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scanAppFolder({required bool silent}) async {
    if (!_usesAppFolder) return;
    try {
      final count = await ref.read(inboxScannerProvider).scan();
      DiagLog.add('앱 폴더 스캔: $count권 추가');
      if (count > 0) {
        _showMessage('앱 폴더에서 $count권을 추가했습니다.');
      } else if (!silent) {
        _showMessage('앱 폴더에 새로 넣은 책이 없습니다. 파일 앱 → 나의 iPhone → $appName 폴더에 넣어 주세요.');
      }
    } catch (error) {
      DiagLog.add('앱 폴더 스캔 실패: $error');
      _showMessage('앱 폴더를 읽지 못했습니다: $error');
    }
  }

  Future<void> _importFiles() async {
    final importer = ref.read(bookImporterProvider);
    try {
      final picked = await importer.pickFiles();
      if (picked == null) return;
      await importer.importBooks(picked.books);
      var count = picked.books.length;
      if (picked.images.isNotEmpty) {
        final title = await _askComicTitle(picked);
        if (title != null) {
          await importer.importImages(picked.images, title);
          count++;
        }
      }
      final skipped = picked.skipped.isEmpty
          ? ''
          : ' (지원하지 않는 파일 ${picked.skipped.length}개 제외)';
      _showMessage('$count권을 추가했습니다.$skipped');
    } catch (error) {
      DiagLog.add('파일 가져오기 실패: $error');
      _showMessage('가져오기에 실패했습니다: $error');
    }
  }

  /// 낱장 이미지를 묶을 만화 제목을 묻는다. 취소하면 null.
  Future<String?> _askComicTitle(PickedFiles picked) async {
    if (!mounted) return null;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: '이미지 ${picked.images.length}장을 만화 한 권으로',
        initialText: picked.suggestedTitle,
        confirmLabel: '추가',
      ),
    );
    final trimmed = title?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _importFolder() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var busyShown = false;
    void showBusy() {
      busyShown = true;
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 24),
                Expanded(child: Text('폴더를 가져오는 중입니다…')),
              ],
            ),
          ),
        ),
      );
    }

    void hideBusy() {
      if (busyShown) navigator.pop();
      busyShown = false;
    }

    try {
      final imported = await ref
          .read(bookImporterProvider)
          .pickAndImportFolder(onBusy: showBusy);
      hideBusy();
      if (imported) _showMessage('폴더를 추가했습니다.');
    } on FormatException catch (error) {
      hideBusy();
      _showMessage(error.message);
    } catch (error) {
      hideBusy();
      _showMessage('가져오기에 실패했습니다: $error');
    }
  }

  void _showImportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('파일 가져오기'),
              subtitle: const Text('txt, epub, zip, cbz, 또는 이미지 여러 장'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFiles();
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('이미지 폴더 가져오기'),
                subtitle: const Text('폴더 하나를 만화 한 권으로 추가'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importFolder();
                },
              ),
            if (_usesAppFolder)
              ListTile(
                leading: const Icon(Icons.drive_folder_upload_outlined),
                title: const Text('앱 폴더에서 가져오기'),
                subtitle: const Text('파일 앱 → 나의 iPhone → $appName에 넣은 폴더와 파일'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanAppFolder(silent: false);
                },
              ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('진단 기록'),
              subtitle: const Text('가져오기가 안 될 때 어디서 멈추는지 확인'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _open(Book book) {
    ref.read(bookRepositoryProvider).markOpened(book.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
  }

  void _toggleSelected(Book book) {
    setState(() {
      if (!_selected.remove(book.id)) _selected.add(book.id);
    });
  }

  Future<void> _renameSelected(List<Book> books) async {
    final book = books.firstWhere((b) => b.id == _selected.single);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: '이름 변경',
        initialText: book.title,
        confirmLabel: '변경',
      ),
    );
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await ref.read(bookRepositoryProvider).rename(book.id, trimmed);
    if (mounted) setState(_selected.clear);
  }

  Future<void> _deleteSelected(List<Book> books) async {
    final targets = books.where((b) => _selected.contains(b.id)).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('책 삭제'),
        content: Text(
          targets.length == 1
              ? '"${targets.single.title}"을(를) 서재에서 삭제할까요?'
              : '${targets.length}권을 서재에서 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final book in targets) {
      await ref.read(bookRepositoryProvider).delete(book.id);
      await ref.read(bookStorageProvider).delete(book.fileName);
    }
    if (mounted) setState(_selected.clear);
  }

  PreferredSizeWidget _appBar(List<Book> books, ReaderSettings settings) {
    if (_selected.isNotEmpty) {
      return AppBar(
        leading: IconButton(
          tooltip: '선택 해제',
          onPressed: () => setState(_selected.clear),
          icon: const Icon(Icons.close),
        ),
        title: Text('${_selected.length}권 선택'),
        actions: [
          if (_selected.length == 1)
            IconButton(
              tooltip: '이름 변경',
              onPressed: () => _renameSelected(books),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: '삭제',
            onPressed: () => _deleteSelected(books),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        leading: IconButton(
          tooltip: '검색 닫기',
          onPressed: () => setState(() {
            _searching = false;
            _query = '';
          }),
          icon: const Icon(Icons.arrow_back),
        ),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: '제목 검색', border: InputBorder.none),
          onChanged: (value) => setState(() => _query = value),
        ),
      );
    }
    final notifier = ref.read(readerSettingsProvider.notifier);
    return AppBar(
      title: const Text('서재'),
      actions: [
        IconButton(
          tooltip: '제목 검색',
          onPressed: () => setState(() => _searching = true),
          icon: const Icon(Icons.search),
        ),
        PopupMenuButton<LibrarySort>(
          tooltip: '정렬',
          icon: const Icon(Icons.sort),
          initialValue: settings.librarySort,
          onSelected: (sort) => notifier.update((s) => s.copyWith(librarySort: sort)),
          itemBuilder: (context) => [
            for (final sort in LibrarySort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
        ),
        IconButton(
          tooltip: settings.libraryGrid ? '목록으로 보기' : '표지로 보기',
          onPressed: () =>
              notifier.update((s) => s.copyWith(libraryGrid: !s.libraryGrid)),
          icon: Icon(settings.libraryGrid ? Icons.view_list : Icons.grid_view),
        ),
      ],
    );
  }

  Widget _body(List<Book> books, ReaderSettings settings) {
    if (books.isEmpty) {
      return const Center(child: Text('아래 + 버튼으로 책을 추가하세요.'));
    }
    final query = _query.trim().toLowerCase();
    final shown = query.isEmpty
        ? books
        : books.where((b) => b.title.toLowerCase().contains(query)).toList();
    if (shown.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    Widget item(Book book) {
      return _BookItem(
        book: book,
        grid: settings.libraryGrid,
        selected: _selected.contains(book.id),
        // 선택 중에는 탭이 열기 대신 선택으로 동작한다.
        onTap: () => _selected.isEmpty ? _open(book) : _toggleSelected(book),
        onLongPress: () => _toggleSelected(book),
      );
    }

    // + 버튼이 마지막 줄을 가리지 않도록 아래를 비워 둔다.
    const bottomSpace = 88.0;
    if (!settings.libraryGrid) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: bottomSpace),
        itemCount: shown.length,
        itemBuilder: (context, index) => item(shown[index]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, bottomSpace),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // 표지(2:3) 아래에 제목 두 줄이 들어갈 높이
        childAspectRatio: 0.54,
      ),
      itemCount: shown.length,
      itemBuilder: (context, index) => item(shown[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    final settings = ref.watch(readerSettingsProvider);
    final list = books.value ?? const <Book>[];
    return Scaffold(
      appBar: _appBar(list, settings),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('서재를 불러오지 못했습니다.\n$error')),
        data: (list) => _body(list, settings),
      ),
      floatingActionButton: _selected.isNotEmpty
          ? null
          : FloatingActionButton(
              onPressed: _showImportMenu,
              tooltip: '가져오기',
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// 글자 하나를 입력받는 대화상자.
/// 닫히는 애니메이션이 끝날 때까지 입력 컨트롤러가 살아 있도록 대화상자가 직접 소유한다.
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialText,
    required this.confirmLabel,
  });

  final String title;
  final String initialText;
  final String confirmLabel;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '제목'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// 서재의 책 한 권. 격자에서는 표지와 제목, 목록에서는 한 줄로 보여 준다.
class _BookItem extends ConsumerWidget {
  const _BookItem({
    required this.book,
    required this.grid,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final bool grid;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 한 번도 열지 않은 책은 진행률이 없다.
    final progress = ref.watch(
      progressMapProvider.select((map) => map.value?[book.id]),
    );
    final format = book.format.name.toUpperCase();

    if (!grid) {
      return ListTile(
        selected: selected,
        selectedTileColor: scheme.secondaryContainer,
        leading: SizedBox(
          width: 40,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BookCover(book: book),
          ),
        ),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          progress == null ? format : '$format · ${(progress * 100).round()}%',
        ),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover(book: book),
                  if (progress != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(value: progress, minHeight: 4),
                    ),
                  if (selected)
                    ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.45),
                      child: Icon(Icons.check_circle, color: scheme.onPrimary, size: 36),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
