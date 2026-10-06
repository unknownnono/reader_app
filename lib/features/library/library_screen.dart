import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../core/diag/diag_log.dart';
import '../../core/utils/natural_compare.dart';
import '../../data/db/app_database.dart';
import '../../domain/reader_settings.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';
import '../transfer/transfer_screen.dart';
import 'book_cover.dart';
import 'import/book_importer.dart';
import 'series.dart';

/// 앱 문서 폴더가 파일 앱에 보이는 플랫폼에서만 "앱 폴더에서 가져오기"를 쓴다.
/// 디버그 빌드에서는 에뮬레이터로 확인할 수 있게 Android에서도 켠다.
bool get _usesAppFolder => Platform.isIOS || kDebugMode;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.series});

  /// 주어지면 서재 전체가 아니라 이 묶음에 든 책만 보여 준다.
  final SeriesRef? series;

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
    // 파일 앱에서 책을 넣고 돌아오면 바로 서재에 나타나게 한다. 묶음 화면에서는 하지 않는다.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (widget.series == null) _scanAppFolder(silent: true);
      },
    );
    if (widget.series == null) _scanAppFolder(silent: true);
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
          child: CupertinoAlertDialog(
            content: Column(
              children: [
                CupertinoActivityIndicator(radius: 12),
                SizedBox(height: 12),
                Text('폴더를 가져오는 중입니다…'),
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

  /// 책을 넣는 방법을 고르는 아이폰식 선택 창
  void _showImportMenu() {
    CupertinoActionSheetAction action(String label, VoidCallback onChosen) {
      return CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
          onChosen();
        },
        child: Text(label),
      );
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('책 넣기'),
        message: const Text('txt, epub, zip, cbz 파일이나 만화 그림 여러 장을 넣을 수 있습니다.'),
        actions: [
          action('파일 고르기', _importFiles),
          if (Platform.isAndroid) action('그림 폴더 고르기', _importFolder),
          if (_usesAppFolder) action('앱 폴더에 넣은 것 가져오기', () => _scanAppFolder(silent: false)),
          action(
            'Wi-Fi로 PC에서 받기',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransferScreen()),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
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
      builder: (context) => CupertinoAlertDialog(
        title: const Text('책 삭제'),
        content: Text(
          targets.length == 1
              ? '"${targets.single.title}"을(를) 삭제할까요?'
              : '${targets.length}권을 삭제할까요?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => setState(_selected.clear),
          child: const Text('취소'),
        ),
        title: Text('${_selected.length}권 선택'),
        actions: [
          if (_selected.length == 1)
            IconButton(
              tooltip: '이름 변경',
              onPressed: () => _renameSelected(books),
              icon: const Icon(CupertinoIcons.pencil),
            ),
          IconButton(
            tooltip: '삭제',
            onPressed: () => _deleteSelected(books),
            icon: Icon(CupertinoIcons.trash, color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: CupertinoSearchTextField(
          autofocus: true,
          placeholder: '제목 검색',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _searching = false;
              _query = '';
            }),
            child: const Text('취소'),
          ),
        ],
      );
    }
    final notifier = ref.read(readerSettingsProvider.notifier);
    final series = widget.series;
    return AppBar(
      // 탭 첫 화면은 큰 제목을 왼쪽에, 묶음 안은 보통 제목을 가운데에 둔다.
      centerTitle: series != null,
      titleSpacing: series == null ? 20 : null,
      title: series == null ? const LargeTitle('파일') : Text(series.name),
      actions: [
        IconButton(
          tooltip: '제목 검색',
          onPressed: () => setState(() => _searching = true),
          icon: const Icon(CupertinoIcons.search),
        ),
        // 묶음 안은 항상 권 순서라 정렬을 고를 일이 없다.
        if (widget.series == null)
          PopupMenuButton<Object>(
            tooltip: '정렬',
            icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
            onSelected: (value) => notifier.update(
              (s) => value is LibrarySort
                  ? s.copyWith(librarySort: value)
                  : s.copyWith(groupSeries: !s.groupSeries),
            ),
            itemBuilder: (context) => [
              for (final sort in LibrarySort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: settings.librarySort == sort,
                  child: Text(sort.label),
                ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'groupSeries',
                checked: settings.groupSeries,
                child: const Text('시리즈로 묶기'),
              ),
            ],
          ),
        IconButton(
          tooltip: settings.libraryGrid ? '목록으로 보기' : '표지로 보기',
          onPressed: () =>
              notifier.update((s) => s.copyWith(libraryGrid: !s.libraryGrid)),
          icon: Icon(
            settings.libraryGrid ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
          ),
        ),
        // 책 넣기는 서재 첫 화면에서만 한다.
        if (widget.series == null)
          IconButton(
            tooltip: '가져오기',
            onPressed: _showImportMenu,
            icon: const Icon(CupertinoIcons.plus),
          ),
      ],
    );
  }

  /// 이 화면에 보일 책. 묶음 화면이면 그 묶음의 책만 권 순서로 고른다.
  List<Book> _scope(List<Book> books) {
    final series = widget.series;
    if (series == null) return books;
    return books.where(series.contains).toList()
      ..sort((a, b) => naturalCompare(a.title, b.title));
  }

  Widget _body(List<Book> allBooks, ReaderSettings settings) {
    final books = _scope(allBooks);
    if (books.isEmpty) {
      if (widget.series != null) {
        return const Center(child: Text('이 묶음에 남은 책이 없습니다.'));
      }
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.folder, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text('아직 넣은 책이 없습니다.'),
              const SizedBox(height: 4),
              Text(
                'txt, epub, 만화 zip·cbz, 그림 폴더를 넣을 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _showImportMenu, child: const Text('책 넣기')),
            ],
          ),
        ),
      );
    }
    final query = _query.trim().toLowerCase();
    final found = query.isEmpty
        ? books
        : books.where((b) => b.title.toLowerCase().contains(query)).toList();
    if (found.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }
    // 검색 중이거나 이미 묶음 안이면 낱권으로 보여 준다.
    final shown = settings.groupSeries && widget.series == null && query.isEmpty
        ? groupSeries(found)
        : [for (final book in found) LibraryEntry.single(book)];

    Widget item(LibraryEntry entry) {
      final book = entry.cover;
      if (entry.isSeries) {
        final count = '${entry.books.length}권';
        return _BookItem(
          book: book,
          title: entry.seriesName!,
          detail: '${book.format.name.toUpperCase()} · $count',
          badge: count,
          grid: settings.libraryGrid,
          selected: false,
          // 선택 중에는 묶음을 건드리지 않는다. 묶음 안의 책은 들어가서 고른다.
          onTap: () {
            if (_selected.isNotEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LibraryScreen(
                  series: SeriesRef(entry.seriesName!, book.format),
                ),
              ),
            );
          },
          onLongPress: null,
        );
      }
      return _BookItem(
        book: book,
        title: book.title,
        grid: settings.libraryGrid,
        selected: _selected.contains(book.id),
        // 선택 중에는 탭이 열기 대신 선택으로 동작한다.
        onTap: () => _selected.isEmpty ? _open(book) : _toggleSelected(book),
        onLongPress: () => _toggleSelected(book),
      );
    }

    if (!settings.libraryGrid) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: shown.length,
        separatorBuilder: (context, index) => const Divider(indent: 76),
        itemBuilder: (context, index) => item(shown[index]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
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
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(child: Text('책 목록을 불러오지 못했습니다.\n$error')),
        data: (list) => _body(list, settings),
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
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          placeholder: '제목',
          clearButtonMode: OverlayVisibilityMode.editing,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// 서재의 한 칸(책 한 권 또는 묶음). 격자에서는 표지와 제목, 목록에서는 한 줄로 보여 준다.
class _BookItem extends ConsumerWidget {
  const _BookItem({
    required this.book,
    required this.title,
    required this.grid,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.detail,
    this.badge,
  });

  /// 표지로 쓸 책. 묶음이면 첫 권이다.
  final Book book;
  final String title;
  final bool grid;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 목록 보기의 둘째 줄. 없으면 형식과 진행률을 보여 준다.
  final String? detail;

  /// 표지 귀퉁이에 붙는 표시. 묶음의 권 수에 쓴다.
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 한 번도 열지 않은 책은 진행률이 없다. 묶음은 진행률을 보여 주지 않는다.
    final progress = detail != null
        ? null
        : ref.watch(progressMapProvider.select((map) => map.value?[book.id]));
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
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          detail ??
              (progress == null ? format : '$format · ${(progress * 100).round()}%'),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle)
            : badge != null
                ? const Icon(Icons.chevron_right)
                : null,
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
                  if (badge != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
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
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
