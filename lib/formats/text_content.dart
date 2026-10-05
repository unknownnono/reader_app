/// 본문에서 그림이 들어갈 자리를 나타내는 글자. 그림 하나가 한 줄을 차지한다.
const imagePlaceholder = '￼';
const imagePlaceholderCode = 0xFFFC;

/// 텍스트 뷰어가 보여 줄 본문. txt와 epub 모두 이 형태로 바꿔서 넘긴다.
class TextContent {
  const TextContent(this.text, {this.toc = const [], this.images = const {}});

  final String text;

  /// 목차. txt는 비어 있다.
  final List<TextTocEntry> toc;

  /// 본문의 [imagePlaceholder] 위치(글자 오프셋) → 책 파일(zip) 안의 그림 경로
  final Map<int, String> images;
}

class TextTocEntry {
  const TextTocEntry(this.title, this.offset);

  final String title;

  /// 본문에서 이 항목이 시작하는 글자 오프셋
  final int offset;
}
