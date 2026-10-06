import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../domain/reading_position.dart';
import '../../../formats/text_content.dart';
import '../../../formats/txt/txt_paginator.dart';
import '../../../formats/zip_entry.dart';
import '../../../providers.dart';
import '../../settings/reader_settings_sheet.dart';
import '../bookmark_list.dart';
import '../reader_bar.dart';
import '../text_search.dart';

const _verticalPadding = 16.0;
const _barHeight = 56.0;

/// 글자를 페이지로 나눠 보여 주는 뷰어. txt와 epub이 함께 쓴다.
class TextRenderer extends ConsumerStatefulWidget {
  const TextRenderer({super.key, required this.book, required this.loader});

  final Book book;

  /// 책 파일 경로를 받아 본문을 읽어 오는 함수. 포맷마다 다르다.
  final Future<TextContent> Function(String path) loader;

  @override
  ConsumerState<TextRenderer> createState() => _TextRendererState();
}

class _TextRendererState extends ConsumerState<TextRenderer> {
  String? _path;
  String? _text;
  List<TextTocEntry> _toc = const [];
  Map<int, String> _images = const {};
  Object? _error;
  int _start = 0;
  bool _showControls = false;

  /// 화면을 그릴 때 쓴 페이지 계산기와 지금 페이지의 끝. 검색·북마크에서 페이지 경계를 찾는 데 쓴다.
  TxtPaginator? _paginator;
  int _pageEnd = 0;

  /// 본문 검색으로 찾아간 말. 그 페이지에서 눈에 띄게 표시한다.
  String? _highlight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = await ref.read(bookStorageProvider).pathFor(widget.book.fileName);
      final content = await widget.loader(path);
      final text = content.text;
      final position = await ref.read(progressRepositoryProvider).get(widget.book.id);
      if (!mounted) return;
      setState(() {
        _path = path;
        _text = text;
        _toc = content.toc;
        _images = content.images;
        _start = position.offset.clamp(0, text.isEmpty ? 0 : text.length - 1);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// 목차와 북마크를 탭으로 나눠 보여 준다. 목차가 없는 책(txt)은 북마크만 나온다.
  void _showContents() {
    final text = _text!;
    // 지금 읽는 위치가 속한 항목을 표시한다.
    final current = _toc.lastIndexWhere((entry) => entry.offset <= _start);
    void open(int offset) {
      Navigator.pop(context);
      setState(() => _showControls = false);
      _goTo(offset);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: DefaultTabController(
            length: _toc.isEmpty ? 1 : 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    if (_toc.isNotEmpty) const Tab(text: '목차'),
                    const Tab(text: '북마크'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      if (_toc.isNotEmpty)
                        ListView.builder(
                          itemCount: _toc.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(
                              _toc[index].title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: index == current,
                            onTap: () => open(_toc[index].offset),
                          ),
                        ),
                      BookmarkList(
                        bookId: widget.book.id,
                        onOpen: (bookmark) => open(bookmark.position),
                        detailOf: (bookmark) => text.isEmpty
                            ? ''
                            : '${(bookmark.position * 100 / text.length).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 지금 보는 페이지에 북마크가 있으면 지우고, 없으면 만든다.
  void _toggleBookmark(List<Bookmark> onThisPage) {
    final repository = ref.read(bookmarkRepositoryProvider);
    if (onThisPage.isNotEmpty) {
      for (final bookmark in onThisPage) {
        repository.delete(bookmark.id);
      }
      return;
    }
    final text = _text!;
    final preview = text
        .substring(_start, (_start + 60).clamp(0, text.length))
        .replaceAll(imagePlaceholder, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    repository.add(
      bookId: widget.book.id,
      position: _start,
      label: preview.isEmpty ? '그림' : preview,
    );
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<(int, String)>(
      MaterialPageRoute(
        builder: (_) => TextSearchScreen(text: _text!, initialQuery: _highlight ?? ''),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _highlight = result.$2;
      _showControls = false;
    });
    _goToContaining(result.$1);
  }

  /// [offset]이 들어 있는 페이지로 간다.
  /// 문단 처음에서 시작하되, 문단이 길어 그 글자가 뒤 페이지로 밀리면 거기까지 넘긴다.
  void _goToContaining(int offset) {
    var start = _snapToLineStart(offset);
    final paginator = _paginator;
    if (paginator != null) {
      for (var turns = 0; turns < 50; turns++) {
        final end = paginator.pageEnd(start);
        if (end > offset || end <= start) break;
        start = end;
      }
    }
    _goTo(start);
  }

  /// 손으로 한 장 넘긴다. 검색어 표시는 찾아간 페이지에서만 보여 주고 지운다.
  void _turnTo(int offset) {
    _highlight = null;
    _goTo(offset);
  }

  /// 검색어가 있으면 그 부분에 바탕색을 칠한다. 글자 배치는 바뀌지 않는다.
  List<TextSpan> _spans(String page, Color markColor) {
    final query = _highlight?.toLowerCase();
    final lower = page.toLowerCase();
    if (query == null || query.isEmpty || lower.length != page.length) {
      return [TextSpan(text: page)];
    }
    final spans = <TextSpan>[];
    var from = 0;
    for (var index = lower.indexOf(query); index != -1; index = lower.indexOf(query, from)) {
      if (index > from) spans.add(TextSpan(text: page.substring(from, index)));
      from = index + query.length;
      spans.add(
        TextSpan(
          text: page.substring(index, from),
          style: TextStyle(backgroundColor: markColor),
        ),
      );
    }
    spans.add(TextSpan(text: page.substring(from)));
    return spans;
  }

  void _goTo(int offset) {
    final text = _text!;
    final start = offset.clamp(0, text.isEmpty ? 0 : text.length - 1);
    if (start == _start) return;
    setState(() => _start = start);
    ref.read(progressRepositoryProvider).save(
          widget.book.id,
          ReadingPosition(
            offset: start,
            progress: text.isEmpty ? 0 : start / text.length,
          ),
        );
  }

  /// 슬라이더로 이동할 때 줄 중간에서 시작하지 않도록 가까운 줄 시작으로 맞춘다.
  int _snapToLineStart(int offset) {
    final newline = _text!.lastIndexOf('\n', offset);
    if (newline >= 0 && offset - newline < 500) return newline + 1;
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: Center(child: Text('파일을 열지 못했습니다.\n$_error')),
      );
    }
    if (text == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final settings = ref.watch(readerSettingsProvider);
    final colors = settings.theme.colors;
    final pagePadding = EdgeInsets.symmetric(
      horizontal: settings.margin,
      vertical: _verticalPadding,
    );
    final style = theme.textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: colors?.text ?? theme.colorScheme.onSurface,
    );
    final strutStyle = StrutStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      forceStrutHeight: true,
    );

    return Scaffold(
      backgroundColor: colors?.background,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final paginator = TxtPaginator(
                  text: text,
                  style: style,
                  strutStyle: strutStyle,
                  pageSize: pagePadding.deflateSize(constraints.biggest),
                );
                _paginator = paginator;
                final end = paginator.pageEnd(_start);
                _pageEnd = end;
                // 여백을 탭해도 넘어가도록 탭 영역은 여백 바깥까지 잡는다.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final x = details.localPosition.dx / constraints.maxWidth;
                    if (x < 1 / 3) {
                      _turnTo(paginator.pageStartBefore(_start));
                    } else if (x > 2 / 3) {
                      if (end < text.length) _turnTo(end);
                    } else {
                      setState(() => _showControls = !_showControls);
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < 0 && end < text.length) _turnTo(end);
                    if (velocity > 0) _turnTo(paginator.pageStartBefore(_start));
                  },
                  child: Padding(
                    padding: pagePadding,
                    child: SizedBox.expand(
                      child: _images.containsKey(_start)
                          ? Image(
                              image: ZipEntryImage(_path!, _images[_start]!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, _) =>
                                  const Center(child: Text('그림을 표시할 수 없습니다.')),
                            )
                          : RichText(
                              text: TextSpan(
                                style: style,
                                children: _spans(
                                  // 그림 자리 글자가 남아 있어도 화면에 찍히지 않게 한다.
                                  text
                                      .substring(_start, end)
                                      .replaceAll(imagePlaceholder, ''),
                                  theme.colorScheme.tertiaryContainer,
                                ),
                              ),
                              strutStyle: strutStyle,
                              textScaler: TextScaler.noScaling,
                            ),
                    ),
                  ),
                );
              },
            ),
            if (_showControls) ...[
              // Slider는 주어진 높이를 다 차지하므로 막대 높이를 고정한다.
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: _barHeight, child: _topBar(theme)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(height: _barHeight, child: _bottomBar(theme, text)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar(ThemeData theme) {
    // 지금 페이지 범위 안에 있는 북마크
    final onThisPage = [
      for (final bookmark
          in ref.watch(bookmarksProvider(widget.book.id)).value ?? const <Bookmark>[])
        if (bookmark.position >= _start && bookmark.position < _pageEnd) bookmark,
    ];
    return ReaderBar(
      top: true,
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
          IconButton(
            tooltip: onThisPage.isEmpty ? '북마크 추가' : '북마크 해제',
            onPressed: () => _toggleBookmark(onThisPage),
            icon: Icon(onThisPage.isEmpty ? CupertinoIcons.bookmark : CupertinoIcons.bookmark_fill),
          ),
          IconButton(
            tooltip: '목차·북마크',
            onPressed: _showContents,
            icon: const Icon(CupertinoIcons.list_bullet),
          ),
          IconButton(
            tooltip: '본문 검색',
            onPressed: _openSearch,
            icon: const Icon(CupertinoIcons.search),
          ),
          IconButton(
            tooltip: '읽기 설정',
            onPressed: () => showReaderSettingsSheet(context),
            icon: const Icon(CupertinoIcons.textformat_size),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme, String text) {
    final progress = text.isEmpty ? 0.0 : _start / text.length;
    return ReaderBar(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: Slider.adaptive(
              value: progress,
              onChanged: (value) =>
                  _goTo(_snapToLineStart((value * text.length).floor())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('${(progress * 100).toStringAsFixed(1)}%'),
          ),
        ],
      ),
    );
  }
}
