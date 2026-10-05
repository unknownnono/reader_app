import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';
import 'package:reader_app/features/reader/comic_layout.dart';
import 'package:reader_app/providers.dart';

void main() {
  test('한 쪽씩 볼 때는 쪽 하나가 화면 하나다', () {
    const layout = ComicLayout(pageCount: 5, doublePage: false);
    expect(layout.unitCount, 5);
    expect(layout.unitOf(3), 3);
    expect(layout.pagesOf(3), [3]);
  });

  test('두 쪽 보기는 표지만 혼자 두고 두 쪽씩 묶는다', () {
    const layout = ComicLayout(pageCount: 6, doublePage: true);
    expect(
      [for (var unit = 0; unit < layout.unitCount; unit++) layout.pagesOf(unit)],
      [
        [0],
        [1, 2],
        [3, 4],
        [5],
      ],
    );
    // 어느 쪽에서든 그 쪽이 들어 있는 화면을 찾을 수 있다.
    for (var page = 0; page < 6; page++) {
      expect(layout.pagesOf(layout.unitOf(page)), contains(page));
    }
  });

  test('두 쪽 보기에서 쪽 수가 홀수여도 빠지는 쪽이 없다', () {
    for (final count in [1, 2, 3, 7]) {
      final layout = ComicLayout(pageCount: count, doublePage: true);
      final all = [
        for (var unit = 0; unit < layout.unitCount; unit++) ...layout.pagesOf(unit),
      ];
      expect(all, List.generate(count, (i) => i), reason: '$count쪽');
    }
  });

  test('다음 권은 만화만 놓고 제목 순으로 바로 다음 책이다', () {
    Book book(int id, String title, BookFormat format) {
      return Book(
        id: id,
        title: title,
        fileName: title,
        format: format,
        addedAt: DateTime(2026),
      );
    }

    final books = [
      book(1, '짱 10', BookFormat.comic),
      book(2, '짱 2', BookFormat.comic),
      book(3, '짱 3 소설판', BookFormat.txt),
      book(4, '짱 9', BookFormat.comic),
    ];
    expect(nextComic(books, books[1])!.title, '짱 9');
    expect(nextComic(books, books[3])!.title, '짱 10');
    expect(nextComic(books, books[0]), isNull);
  });
}
