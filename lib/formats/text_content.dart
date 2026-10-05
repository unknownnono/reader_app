/// 텍스트 뷰어가 보여 줄 본문. txt와 epub 모두 이 형태로 바꿔서 넘긴다.
class TextContent {
  const TextContent(this.text, {this.toc = const []});

  final String text;

  /// 목차. txt는 비어 있다.
  final List<TextTocEntry> toc;
}

class TextTocEntry {
  const TextTocEntry(this.title, this.offset);

  final String title;

  /// 본문에서 이 항목이 시작하는 글자 오프셋
  final int offset;
}
