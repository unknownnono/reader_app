import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../domain/reading_position.dart';
import '../../../formats/text_content.dart';
import '../../../formats/txt/txt_paginator.dart';
import '../../../formats/zip_entry.dart';
import '../../../providers.dart';

const _pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
const _lineHeight = 1.7;
const _barHeight = 56.0;
const _minFontSize = 12.0;
const _maxFontSize = 32.0;

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

  void _showToc() {
    // 지금 읽는 위치가 속한 항목을 표시한다.
    final current = _toc.lastIndexWhere((entry) => entry.offset <= _start);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          itemCount: _toc.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(_toc[index].title, maxLines: 2, overflow: TextOverflow.ellipsis),
            selected: index == current,
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() => _showControls = false);
              _goTo(_toc[index].offset);
            },
          ),
        ),
      ),
    );
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
    final fontSize = ref.watch(txtFontSizeProvider);
    final style = theme.textTheme.bodyLarge!.copyWith(
      fontSize: fontSize,
      height: _lineHeight,
      color: theme.colorScheme.onSurface,
    );
    final strutStyle = StrutStyle(
      fontSize: fontSize,
      height: _lineHeight,
      forceStrutHeight: true,
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final paginator = TxtPaginator(
                  text: text,
                  style: style,
                  strutStyle: strutStyle,
                  pageSize: _pagePadding.deflateSize(constraints.biggest),
                );
                final end = paginator.pageEnd(_start);
                // 여백을 탭해도 넘어가도록 탭 영역은 여백 바깥까지 잡는다.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final x = details.localPosition.dx / constraints.maxWidth;
                    if (x < 1 / 3) {
                      _goTo(paginator.pageStartBefore(_start));
                    } else if (x > 2 / 3) {
                      if (end < text.length) _goTo(end);
                    } else {
                      setState(() => _showControls = !_showControls);
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < 0 && end < text.length) _goTo(end);
                    if (velocity > 0) _goTo(paginator.pageStartBefore(_start));
                  },
                  child: Padding(
                    padding: _pagePadding,
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
                                // 그림 자리 글자가 남아 있어도 화면에 찍히지 않게 한다.
                                text: text
                                    .substring(_start, end)
                                    .replaceAll(imagePlaceholder, ''),
                                style: style,
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
                child: SizedBox(height: _barHeight, child: _topBar(theme, fontSize)),
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

  Widget _topBar(ThemeData theme, double fontSize) {
    final notifier = ref.read(txtFontSizeProvider.notifier);
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
          if (_toc.isNotEmpty)
            IconButton(
              tooltip: '목차',
              onPressed: _showToc,
              icon: const Icon(Icons.list),
            ),
          IconButton(
            tooltip: '글자 작게',
            onPressed: fontSize > _minFontSize ? () => notifier.set(fontSize - 1) : null,
            icon: const Icon(Icons.text_decrease),
          ),
          Text('${fontSize.round()}'),
          IconButton(
            tooltip: '글자 크게',
            onPressed: fontSize < _maxFontSize ? () => notifier.set(fontSize + 1) : null,
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme, String text) {
    final progress = text.isEmpty ? 0.0 : _start / text.length;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: Slider(
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
