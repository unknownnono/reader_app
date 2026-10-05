class BookMetadata {
  const BookMetadata({required this.title, this.author});

  final String title;
  final String? author;
}

class TocEntry {
  const TocEntry({required this.title, required this.section});

  final String title;
  final int section;
}

/// 포맷별 파서가 구현하는 공통 인터페이스.
/// txt/epub/comic 구현은 각각 formats/ 아래 폴더에 둔다.
abstract class BookSource {
  Future<void> open();
  Future<void> close();
  Future<BookMetadata> loadMetadata();

  /// txt와 만화는 비어 있을 수 있다.
  Future<List<TocEntry>> loadToc();
}
