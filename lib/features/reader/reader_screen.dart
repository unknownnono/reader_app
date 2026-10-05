import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';
import 'renderers/comic_renderer.dart';
import 'renderers/text_renderer.dart';

/// 뷰어 공통 껍데기. 포맷을 보고 렌더러를 고른다.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return switch (book.format) {
      BookFormat.txt => TextRenderer(book: book),
      BookFormat.comic => ComicRenderer(book: book),
      // TODO: 4단계에서 epub 렌더러로 교체
      BookFormat.epub => _placeholder('epub 뷰어는 4단계에서 구현합니다.'),
    };
  }

  Widget _placeholder(String message) {
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: Center(child: Text(message)),
    );
  }
}
