import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/book_storage.dart';
import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';
import '../../formats/comic/comic_archive.dart';
import '../../formats/epub/epub_parser.dart';
import '../../formats/zip_entry.dart';
import '../../providers.dart';

/// 디코딩할 표지의 가로 픽셀. 원본 크기로 두면 격자에 책이 많을 때 메모리를 많이 쓴다.
const _coverCacheWidth = 360;

/// 책 표지. 만화는 첫 장, epub은 표지 그림을 쓰고, 없으면 제목을 적은 판을 보여 준다.
class BookCover extends ConsumerWidget {
  const BookCover({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = _Placeholder(book: book);
    if (book.format == BookFormat.txt) return placeholder;
    return Image(
      image: ResizeImage(
        _CoverImage(book, ref.watch(bookStorageProvider)),
        width: _coverCacheWidth,
      ),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, _) => frame == null ? placeholder : child,
      errorBuilder: (context, error, _) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              switch (book.format) {
                BookFormat.txt => Icons.description_outlined,
                BookFormat.epub => Icons.menu_book_outlined,
                BookFormat.comic => Icons.photo_library_outlined,
              },
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends ImageProvider<_CoverImage> {
  const _CoverImage(this.book, this.storage);

  final Book book;
  final BookStorage storage;

  @override
  Future<_CoverImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(_CoverImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final path = await storage.pathFor(book.fileName);
    final Uint8List bytes;
    if (book.format == BookFormat.comic) {
      final comic = await ComicArchive.open(path);
      if (comic.pageCount == 0) throw StateError('표지로 쓸 그림이 없습니다.');
      bytes = await comic.readPage(0);
    } else {
      final cover = await Isolate.run(() => findEpubCover(path));
      if (cover == null) throw StateError('표지로 쓸 그림이 없습니다.');
      bytes = await readZipEntry(path, cover);
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    return other is _CoverImage && other.book.id == book.id;
  }

  @override
  int get hashCode => book.id.hashCode;
}
