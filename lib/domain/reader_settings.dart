import 'dart:ui';

/// 읽기 화면 배경. [system]은 기기의 밝게/어둡게 설정을 따른다.
enum ReaderTheme {
  system('자동'),
  light('밝게'),
  sepia('세피아'),
  dark('어둡게');

  const ReaderTheme(this.label);

  final String label;

  /// 배경색과 글자색. [system]은 앱 테마를 그대로 쓰므로 null.
  ({Color background, Color text})? get colors => switch (this) {
        ReaderTheme.system => null,
        ReaderTheme.light => (
            background: const Color(0xFFFAF8F5),
            text: const Color(0xFF1F1F1F),
          ),
        ReaderTheme.sepia => (
            background: const Color(0xFFF4ECD8),
            text: const Color(0xFF5B4636),
          ),
        ReaderTheme.dark => (
            background: const Color(0xFF121212),
            text: const Color(0xFFCFCFCF),
          ),
      };
}

/// 만화 보기 방식
enum ComicMode {
  paged('한 쪽씩 넘기기'),
  vertical('세로 스크롤');

  const ComicMode(this.label);

  final String label;
}

/// 서재 정렬 방식
enum LibrarySort {
  recent('최근 읽은 순'),
  title('제목 순'),
  added('추가한 순');

  const LibrarySort(this.label);

  final String label;
}

/// 읽기 화면과 서재 설정. 앱을 꺼도 유지된다.
class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.margin = 20,
    this.theme = ReaderTheme.system,
    this.comicRightToLeft = false,
    this.comicMode = ComicMode.paged,
    this.comicDoublePage = true,
    this.libraryGrid = true,
    this.librarySort = LibrarySort.recent,
  });

  static const minFontSize = 12.0;
  static const maxFontSize = 36.0;
  static const minLineHeight = 1.2;
  static const maxLineHeight = 2.4;
  static const minMargin = 8.0;
  static const maxMargin = 48.0;

  final double fontSize;
  final double lineHeight;

  /// 본문 좌우 여백
  final double margin;
  final ReaderTheme theme;

  /// 만화 넘김 방향. 일본 만화는 오른쪽에서 왼쪽으로 읽는다.
  final bool comicRightToLeft;
  final ComicMode comicMode;

  /// 화면을 가로로 돌렸을 때 두 쪽을 나란히 보여 줄지. 한 쪽씩 넘기기에서만 쓴다.
  final bool comicDoublePage;

  /// 서재를 표지 격자로 볼지(true) 목록으로 볼지(false)
  final bool libraryGrid;
  final LibrarySort librarySort;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    ReaderTheme? theme,
    bool? comicRightToLeft,
    ComicMode? comicMode,
    bool? comicDoublePage,
    bool? libraryGrid,
    LibrarySort? librarySort,
  }) {
    return ReaderSettings(
      fontSize: (fontSize ?? this.fontSize).clamp(minFontSize, maxFontSize),
      lineHeight: (lineHeight ?? this.lineHeight).clamp(minLineHeight, maxLineHeight),
      margin: (margin ?? this.margin).clamp(minMargin, maxMargin),
      theme: theme ?? this.theme,
      comicRightToLeft: comicRightToLeft ?? this.comicRightToLeft,
      comicMode: comicMode ?? this.comicMode,
      comicDoublePage: comicDoublePage ?? this.comicDoublePage,
      libraryGrid: libraryGrid ?? this.libraryGrid,
      librarySort: librarySort ?? this.librarySort,
    );
  }
}
