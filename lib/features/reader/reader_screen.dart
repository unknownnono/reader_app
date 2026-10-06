import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';
import '../../formats/epub/epub_parser.dart';
import '../../formats/text_content.dart';
import '../../formats/txt/txt_decoder.dart';
import '../../formats/txt/txt_toc.dart';
import 'reading_session.dart';
import 'renderers/comic_renderer.dart';
import 'renderers/text_renderer.dart';

/// 뷰어 공통 껍데기. 포맷을 보고 렌더러를 고른다.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return ReadingSession(
      child: switch (book.format) {
        BookFormat.txt => TextRenderer(book: book, loader: _loadTxt),
        BookFormat.epub => TextRenderer(book: book, loader: loadEpub),
        BookFormat.comic => ComicRenderer(book: book),
      },
    );
  }
}

Future<TextContent> _loadTxt(String path) async {
  final text = await decodeTxt(await File(path).readAsBytes());
  return TextContent(text, toc: detectTxtToc(text));
}
