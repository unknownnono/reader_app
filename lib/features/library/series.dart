import '../../core/utils/natural_compare.dart';
import '../../data/db/app_database.dart';
import '../../domain/book_format.dart';

/// 제목 끝의 권 번호. "짱 01", "나루토 12권", "원피스 vol.3", "베르세르크 v07", "책 (2)" 등을 잡는다.
final _volumeSuffix = RegExp(
  r'[\s_\-.,(\[]*(?:제\s*)?(?:vol(?:ume)?\.?|v|#)?\s*\d+\s*(?:권|화|부|편|집)?[\s)\]]*$',
  caseSensitive: false,
);

/// 권 번호를 뗀 시리즈 이름. 번호가 없거나 떼고 나면 남는 게 없으면 null.
String? seriesNameOf(String title) {
  final match = _volumeSuffix.firstMatch(title);
  if (match == null) return null;
  final name = title.substring(0, match.start).trim();
  return name.isEmpty ? null : name;
}

/// 묶음 하나를 가리킨다. 이름이 같아도 형식이 다르면 다른 묶음이다.
class SeriesRef {
  const SeriesRef(this.name, this.format);

  final String name;
  final BookFormat format;

  bool contains(Book book) {
    return book.format == format &&
        seriesNameOf(book.title)?.toLowerCase() == name.toLowerCase();
  }
}

/// 서재에 한 칸으로 보이는 것. 책 한 권이거나, 권 번호만 다른 책들의 묶음이다.
class LibraryEntry {
  const LibraryEntry.single(Book book)
      : seriesName = null,
        books = const [],
        _single = book;

  const LibraryEntry.series(String this.seriesName, this.books) : _single = null;

  /// 묶음이면 시리즈 이름, 낱권이면 null
  final String? seriesName;

  /// 묶음에 든 책(권 순서). 낱권이면 비어 있다.
  final List<Book> books;
  final Book? _single;

  bool get isSeries => seriesName != null;

  /// 표지와 형식을 대표하는 책. 묶음은 첫 권이다.
  Book get cover => _single ?? books.first;
}

/// [books]의 순서를 지키면서 같은 시리즈를 한 칸으로 묶는다.
/// 묶음은 그 안에서 가장 앞에 있던 책의 자리에 놓이고, 묶음 안은 항상 권 순서다.
/// 같은 형식의 책이 두 권 이상일 때만 묶는다.
List<LibraryEntry> groupSeries(List<Book> books) {
  String? keyOf(Book book) {
    final name = seriesNameOf(book.title);
    return name == null ? null : '${book.format.name}\n${name.toLowerCase()}';
  }

  final members = <String, List<Book>>{};
  for (final book in books) {
    final key = keyOf(book);
    if (key != null) members.putIfAbsent(key, () => []).add(book);
  }

  final entries = <LibraryEntry>[];
  final placed = <String>{};
  for (final book in books) {
    final key = keyOf(book);
    final group = key == null ? null : members[key];
    if (group == null || group.length < 2) {
      entries.add(LibraryEntry.single(book));
    } else if (placed.add(key!)) {
      entries.add(
        LibraryEntry.series(
          seriesNameOf(group.first.title)!,
          [...group]..sort((a, b) => naturalCompare(a.title, b.title)),
        ),
      );
    }
  }
  return entries;
}
