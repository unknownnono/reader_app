import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../data/db/app_database.dart';
import '../../../domain/reader_settings.dart';
import '../../../domain/reading_position.dart';
import '../../../formats/comic/comic_archive.dart';
import '../../../providers.dart';
import '../../settings/comic_settings_sheet.dart';
import '../bookmark_list.dart';
import '../comic_layout.dart';
import '../reader_screen.dart';

const _barHeight = 56.0;
const _pageTurn = Duration(milliseconds: 200);

/// 만화의 한 쪽. Flutter 이미지 캐시가 디코딩 결과를 관리한다.
class ComicPageImage extends ImageProvider<ComicPageImage> {
  const ComicPageImage(this.archive, this.index);

  final ComicArchive archive;
  final int index;

  @override
  Future<ComicPageImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(ComicPageImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await archive.readPage(index);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    return other is ComicPageImage &&
        identical(other.archive, archive) &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(identityHashCode(archive), index);
}

/// 화면을 그리는 방식. 바뀌면 스크롤 컨트롤러를 새로 만든다.
enum _View { single, double, vertical }

class ComicRenderer extends ConsumerStatefulWidget {
  const ComicRenderer({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ComicRenderer> createState() => _ComicRendererState();
}

class _ComicRendererState extends ConsumerState<ComicRenderer> {
  ComicArchive? _archive;
  Object? _error;

  /// 지금 보는 쪽. 두 쪽 보기에서는 화면에 보이는 첫 쪽이다.
  int _page = 0;

  /// 마지막 장을 넘겨 "다음 권" 화면에 있는지
  bool _atEnd = false;
  bool _showControls = false;

  _View? _view;
  ComicLayout _layout = const ComicLayout(pageCount: 0, doublePage: false);
  PageController? _pageController;
  ItemScrollController? _listController;
  ItemPositionsListener? _listPositions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _listPositions?.itemPositions.removeListener(_onListScrolled);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final path = await ref.read(bookStorageProvider).pathFor(widget.book.fileName);
      final archive = await ComicArchive.open(path);
      if (archive.pageCount == 0) {
        throw const FormatException('이미지가 없습니다.');
      }
      final position = await ref.read(progressRepositoryProvider).get(widget.book.id);
      if (!mounted) return;
      setState(() {
        _archive = archive;
        _page = position.section.clamp(0, archive.pageCount - 1);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// 보기 방식이 바뀌면 지금 쪽에서 시작하는 새 컨트롤러로 갈아 끼운다.
  void _useView(_View view) {
    if (_view == view) return;
    final old = _pageController;
    if (old != null) {
      // 이전 화면이 아직 붙어 있으므로 이번 프레임이 끝난 뒤에 정리한다.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _listPositions?.itemPositions.removeListener(_onListScrolled);
    _pageController = null;
    _listController = null;
    _listPositions = null;
    if (view == _View.vertical) {
      _listController = ItemScrollController();
      _listPositions = ItemPositionsListener.create()
        ..itemPositions.addListener(_onListScrolled);
    } else {
      _pageController = PageController(
        initialPage: _atEnd ? _layout.unitCount : _layout.unitOf(_page),
      );
    }
    _view = view;
  }

  /// [first]부터 [last]까지의 쪽이 화면에 보이게 됐을 때 부른다.
  void _onPagesShown(int first, int last) {
    final archive = _archive!;
    if (first == _page && !_atEnd) return;
    setState(() {
      _page = first;
      _atEnd = false;
    });
    ref.read(progressRepositoryProvider).save(
          widget.book.id,
          ReadingPosition(section: first, progress: (last + 1) / archive.pageCount),
        );
    // 넘기는 방향 양쪽을 미리 읽어 두어 다음 장이 바로 뜨게 한다.
    for (final next in [last + 1, last + 2, first - 1]) {
      if (next >= 0 && next < archive.pageCount) {
        precacheImage(ComicPageImage(archive, next), context);
      }
    }
  }

  void _onUnitChanged(int unit) {
    if (unit >= _layout.unitCount) {
      setState(() => _atEnd = true);
      return;
    }
    final pages = _layout.pagesOf(unit);
    _onPagesShown(pages.first, pages.last);
  }

  void _onListScrolled() {
    final visible = _listPositions!.itemPositions.value
        .where((position) => position.itemTrailingEdge > 0)
        .map((position) => position.index);
    if (visible.isEmpty) return;
    final first = visible.reduce((a, b) => a < b ? a : b);
    if (first >= _archive!.pageCount) {
      if (!_atEnd) setState(() => _atEnd = true);
    } else {
      _onPagesShown(first, first);
    }
  }

  void _turn({required bool forward}) {
    if (_view == _View.vertical) {
      final target = _atEnd ? _layout.pageCount - 1 : _page + (forward ? 1 : -1);
      if (target < 0 || target > _layout.pageCount) return;
      _listController!.scrollTo(index: target, duration: _pageTurn);
    } else if (forward) {
      _pageController!.nextPage(duration: _pageTurn, curve: Curves.easeOut);
    } else {
      _pageController!.previousPage(duration: _pageTurn, curve: Curves.easeOut);
    }
  }

  void _jumpTo(int page) {
    if (_view == _View.vertical) {
      _listController!.jumpTo(index: page);
    } else {
      _pageController!.jumpToPage(_layout.unitOf(page));
    }
  }

  void _onTap(TapUpDetails details) {
    // 갤러리가 페이지 옵션을 캐시해 두므로 방향은 탭 시점에 다시 읽는다.
    final rightToLeft = _view != _View.vertical &&
        ref.read(readerSettingsProvider).comicRightToLeft;
    final x = details.globalPosition.dx / MediaQuery.sizeOf(context).width;
    final leftSide = x < 1 / 3;
    final rightSide = x > 2 / 3;
    if (!leftSide && !rightSide) {
      setState(() => _showControls = !_showControls);
    } else {
      _turn(forward: leftSide == rightToLeft);
    }
  }

  void _openNext(Book next) {
    ref.read(bookRepositoryProvider).markOpened(next.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archive = _archive;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: Center(child: Text('파일을 열지 못했습니다.\n$_error')),
      );
    }
    if (archive == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final view = settings.comicMode == ComicMode.vertical
        ? _View.vertical
        : settings.comicDoublePage && landscape
            ? _View.double
            : _View.single;
    _layout = ComicLayout(pageCount: archive.pageCount, doublePage: view == _View.double);
    _useView(view);
    final rightToLeft = view != _View.vertical && settings.comicRightToLeft;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (view == _View.vertical)
              _verticalList(archive)
            else
              _gallery(archive, view, rightToLeft),
            if (_showControls) ...[
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: _barHeight, child: _topBar(theme)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: _barHeight,
                  child: _bottomBar(theme, archive, rightToLeft),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _endPanel() {
    return _EndPanel(
      next: ref.watch(nextComicProvider(widget.book)),
      onOpenNext: _openNext,
    );
  }

  Widget _gallery(ComicArchive archive, _View view, bool rightToLeft) {
    return PhotoViewGallery.builder(
      // 보기 방식이 바뀌면 새 컨트롤러로 처음부터 다시 만든다.
      key: ValueKey(view),
      // 마지막 화면 뒤에 "다음 권" 화면을 하나 더 둔다.
      itemCount: _layout.unitCount + 1,
      pageController: _pageController,
      reverse: rightToLeft,
      onPageChanged: _onUnitChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator()),
      builder: (context, unit) {
        if (unit >= _layout.unitCount) {
          return PhotoViewGalleryPageOptions.customChild(
            disableGestures: true,
            child: _endPanel(),
          );
        }
        final pages = _layout.pagesOf(unit);
        if (view == _View.single) {
          return PhotoViewGalleryPageOptions(
            imageProvider: ComicPageImage(archive, pages.single),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            onTapUp: (context, details, value) => _onTap(details),
          );
        }
        return PhotoViewGalleryPageOptions.customChild(
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          onTapUp: (context, details, value) => _onTap(details),
          child: _Spread(archive: archive, pages: pages, rightToLeft: rightToLeft),
        );
      },
    );
  }

  Widget _verticalList(ComicArchive archive) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _onTap,
      child: ScrollablePositionedList.builder(
        itemCount: archive.pageCount + 1,
        initialScrollIndex: _atEnd ? archive.pageCount : _page,
        itemScrollController: _listController,
        itemPositionsListener: _listPositions,
        itemBuilder: (context, index) {
          if (index >= archive.pageCount) {
            return SizedBox(height: 320, child: _endPanel());
          }
          return Image(
            image: ComicPageImage(archive, index),
            width: double.infinity,
            fit: BoxFit.fitWidth,
            // 그림 크기를 알기 전에는 대략 한 쪽 높이만큼 자리를 잡아 둔다.
            frameBuilder: (context, child, frame, _) => frame != null
                ? child
                : AspectRatio(
                    aspectRatio: 2 / 3,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, _) => const SizedBox(
              height: 200,
              child: Center(
                child: Text('그림을 표시할 수 없습니다.', style: TextStyle(color: Colors.white70)),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleBookmark(List<Bookmark> onThisPage) {
    final repository = ref.read(bookmarkRepositoryProvider);
    if (onThisPage.isNotEmpty) {
      for (final bookmark in onThisPage) {
        repository.delete(bookmark.id);
      }
    } else {
      repository.add(bookId: widget.book.id, position: _page, label: '${_page + 1}쪽');
    }
  }

  void _showBookmarks() {
    final pageCount = _layout.pageCount;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: BookmarkList(
          bookId: widget.book.id,
          detailOf: (bookmark) => '전체 $pageCount쪽',
          onOpen: (bookmark) {
            Navigator.pop(sheetContext);
            setState(() => _showControls = false);
            _jumpTo(bookmark.position.clamp(0, pageCount - 1));
          },
        ),
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    // 지금 화면에 보이는 쪽에 걸린 북마크
    final shown = _atEnd ? const <int>[] : _layout.pagesOf(_layout.unitOf(_page));
    final onThisPage = [
      for (final bookmark
          in ref.watch(bookmarksProvider(widget.book.id)).value ?? const <Bookmark>[])
        if (shown.contains(bookmark.position)) bookmark,
    ];
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          const BackButton(),
          Expanded(
            child: Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (!_atEnd)
            IconButton(
              tooltip: onThisPage.isEmpty ? '북마크 추가' : '북마크 해제',
              onPressed: () => _toggleBookmark(onThisPage),
              icon: Icon(onThisPage.isEmpty ? Icons.bookmark_border : Icons.bookmark),
            ),
          IconButton(
            tooltip: '북마크 목록',
            onPressed: _showBookmarks,
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: '만화 설정',
            onPressed: () => showComicSettingsSheet(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme, ComicArchive archive, bool rightToLeft) {
    final last = archive.pageCount - 1;
    final shown = _layout.pagesOf(_layout.unitOf(_page));
    final label = _atEnd
        ? '끝'
        : shown.length == 2
            ? '${shown.first + 1}-${shown.last + 1} / ${archive.pageCount}'
            : '${_page + 1} / ${archive.pageCount}';
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            // 넘기는 방향과 막대 방향을 맞춘다.
            child: Directionality(
              textDirection: rightToLeft ? TextDirection.rtl : TextDirection.ltr,
              child: Slider(
                value: _atEnd ? last.toDouble() : _page.toDouble(),
                max: last == 0 ? 1 : last.toDouble(),
                divisions: last == 0 ? null : last,
                onChanged: last == 0 ? null : (value) => _jumpTo(value.round()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

/// 가로 화면에서 나란히 보여 주는 두 쪽
class _Spread extends StatelessWidget {
  const _Spread({required this.archive, required this.pages, required this.rightToLeft});

  final ComicArchive archive;
  final List<int> pages;
  final bool rightToLeft;

  @override
  Widget build(BuildContext context) {
    if (pages.length == 1) {
      return Image(image: ComicPageImage(archive, pages.single), fit: BoxFit.contain);
    }
    // 책을 펼친 것처럼 두 쪽이 가운데에서 맞닿게 한다.
    return Directionality(
      textDirection: rightToLeft ? TextDirection.rtl : TextDirection.ltr,
      child: Row(
        children: [
          for (final (index, page) in pages.indexed)
            Expanded(
              child: Image(
                image: ComicPageImage(archive, page),
                fit: BoxFit.contain,
                alignment: index == 0
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
              ),
            ),
        ],
      ),
    );
  }
}

/// 마지막 장 다음에 나오는 화면. 다음 권이 있으면 바로 이어서 열 수 있다.
class _EndPanel extends StatelessWidget {
  const _EndPanel({required this.next, required this.onOpenNext});

  final Book? next;
  final void Function(Book next) onOpenNext;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('마지막 장입니다.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            if (next != null) ...[
              FilledButton(
                onPressed: () => onOpenNext(next),
                child: const Text('다음 권 열기'),
              ),
              const SizedBox(height: 8),
              Text(
                next.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ] else
              const Text('다음 권이 없습니다.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('서재로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
