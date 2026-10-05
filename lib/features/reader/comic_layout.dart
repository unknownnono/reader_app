/// 만화의 쪽을 화면 단위로 묶는 방법.
///
/// 한 쪽씩 볼 때는 쪽 하나가 화면 하나다. 두 쪽 보기에서는 표지(첫 쪽)만 혼자 두고
/// 그 뒤로 두 쪽씩 묶는다: [0], [1, 2], [3, 4], …
class ComicLayout {
  const ComicLayout({required this.pageCount, required this.doublePage});

  final int pageCount;
  final bool doublePage;

  /// 화면 수
  int get unitCount {
    if (!doublePage || pageCount == 0) return pageCount;
    return pageCount ~/ 2 + 1;
  }

  /// [page]가 들어 있는 화면
  int unitOf(int page) {
    if (!doublePage || page == 0) return page;
    return (page + 1) ~/ 2;
  }

  /// [unit] 화면에 보이는 쪽들
  List<int> pagesOf(int unit) {
    if (!doublePage || unit == 0) return [unit];
    return [
      for (final page in [unit * 2 - 1, unit * 2])
        if (page < pageCount) page,
    ];
  }
}
