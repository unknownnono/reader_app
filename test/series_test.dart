import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/data/db/app_database.dart';
import 'package:reader_app/domain/book_format.dart';
import 'package:reader_app/features/library/series.dart';

void main() {
  test('제목 끝의 권 번호를 떼어 시리즈 이름을 얻는다', () {
    expect(seriesNameOf('짱 01'), '짱');
    expect(seriesNameOf('나루토 12권'), '나루토');
    expect(seriesNameOf('원피스 vol.3'), '원피스');
    expect(seriesNameOf('베르세르크_v07'), '베르세르크');
    expect(seriesNameOf('드래곤볼 제 5 권'), '드래곤볼');
    expect(seriesNameOf('슬램덩크 (2)'), '슬램덩크');
    expect(seriesNameOf('20세기 소년 03'), '20세기 소년');
  });

  test('번호가 없거나 번호뿐인 제목은 시리즈가 아니다', () {
    expect(seriesNameOf('어린 왕자'), isNull);
    expect(seriesNameOf('1984'), isNull);
    expect(seriesNameOf('01'), isNull);
  });

  group('groupSeries', () {
    var nextId = 0;
    Book book(String title, [BookFormat format = BookFormat.comic]) {
      return Book(
        id: nextId++,
        title: title,
        fileName: title,
        format: format,
        addedAt: DateTime(2026),
      );
    }

    String describe(LibraryEntry entry) {
      return entry.isSeries
          ? '${entry.seriesName}[${entry.books.map((b) => b.title).join(', ')}]'
          : entry.cover.title;
    }

    test('권 번호만 다른 책을 한 칸으로 묶고 묶음 안은 권 순서로 둔다', () {
      final entries = groupSeries([
        book('짱 10'),
        book('어린 왕자', BookFormat.epub),
        book('짱 2'),
        book('나루토 1'),
        book('짱 1'),
      ]);
      expect(entries.map(describe), [
        '짱[짱 1, 짱 2, 짱 10]',
        '어린 왕자',
        '나루토 1',
      ]);
      // 표지는 첫 권이다.
      expect(entries.first.cover.title, '짱 1');
    });

    test('형식이 다르면 이름이 같아도 묶지 않는다', () {
      final entries = groupSeries([
        book('짱 1'),
        book('짱 2', BookFormat.txt),
      ]);
      expect(entries.map(describe), ['짱 1', '짱 2']);
    });
  });
}
