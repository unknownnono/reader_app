import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../data/db/app_database.dart';
import '../../../domain/reading_position.dart';
import '../../../formats/comic/comic_archive.dart';
import '../../../providers.dart';

const _barHeight = 56.0;
const _pageTurn = Duration(milliseconds: 200);

/// 압축 파일 안의 한 페이지. Flutter 이미지 캐시가 디코딩 결과를 관리한다.
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

class ComicRenderer extends ConsumerStatefulWidget {
  const ComicRenderer({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ComicRenderer> createState() => _ComicRendererState();
}

class _ComicRendererState extends ConsumerState<ComicRenderer> {
  ComicArchive? _archive;
  PageController? _controller;
  Object? _error;
  int _page = 0;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      final page = position.section.clamp(0, archive.pageCount - 1);
      setState(() {
        _archive = archive;
        _page = page;
        _controller = PageController(initialPage: page);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _onPageChanged(int page) {
    final archive = _archive!;
    setState(() => _page = page);
    ref.read(progressRepositoryProvider).save(
          widget.book.id,
          ReadingPosition(section: page, progress: (page + 1) / archive.pageCount),
        );
    // 넘기는 방향 양쪽을 미리 읽어 두어 다음 장이 바로 뜨게 한다.
    for (final next in [page + 1, page + 2, page - 1]) {
      if (next >= 0 && next < archive.pageCount) {
        precacheImage(ComicPageImage(archive, next), context);
      }
    }
  }

  void _onTap(TapUpDetails details) {
    // 갤러리가 페이지 옵션을 캐시해 두므로 방향은 탭 시점에 다시 읽는다.
    final rightToLeft = ref.read(readerSettingsProvider).comicRightToLeft;
    final x = details.globalPosition.dx / MediaQuery.sizeOf(context).width;
    final leftSide = x < 1 / 3;
    final rightSide = x > 2 / 3;
    if (!leftSide && !rightSide) {
      setState(() => _showControls = !_showControls);
    } else if (leftSide == rightToLeft) {
      _controller!.nextPage(duration: _pageTurn, curve: Curves.easeOut);
    } else {
      _controller!.previousPage(duration: _pageTurn, curve: Curves.easeOut);
    }
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
    final rightToLeft = ref.watch(
      readerSettingsProvider.select((settings) => settings.comicRightToLeft),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: archive.pageCount,
              pageController: _controller,
              reverse: rightToLeft,
              onPageChanged: _onPageChanged,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) =>
                  const Center(child: CircularProgressIndicator()),
              builder: (context, index) => PhotoViewGalleryPageOptions(
                imageProvider: ComicPageImage(archive, index),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                onTapUp: (context, details, value) => _onTap(details),
              ),
            ),
            if (_showControls) ...[
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: _barHeight, child: _topBar(theme, rightToLeft)),
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

  Widget _topBar(ThemeData theme, bool rightToLeft) {
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
          TextButton.icon(
            onPressed: () =>
                ref
                    .read(readerSettingsProvider.notifier)
                    .update((s) => s.copyWith(comicRightToLeft: !rightToLeft)),
            icon: Icon(rightToLeft ? Icons.arrow_back : Icons.arrow_forward),
            label: Text(rightToLeft ? '오른쪽→왼쪽' : '왼쪽→오른쪽'),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme, ComicArchive archive, bool rightToLeft) {
    final last = archive.pageCount - 1;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            // 넘기는 방향과 막대 방향을 맞춘다.
            child: Directionality(
              textDirection: rightToLeft ? TextDirection.rtl : TextDirection.ltr,
              child: Slider(
                value: _page.toDouble(),
                max: last == 0 ? 1 : last.toDouble(),
                divisions: last == 0 ? null : last,
                onChanged: last == 0
                    ? null
                    : (value) => _controller!.jumpToPage(value.round()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('${_page + 1} / ${archive.pageCount}'),
          ),
        ],
      ),
    );
  }
}
