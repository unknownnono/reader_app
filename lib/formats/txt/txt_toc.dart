import '../text_content.dart';

/// 장 제목으로 보이는 줄. 줄 맨 앞에서 시작하고 줄 전체가 짧아야 한다.
///
/// - "제 1 장", "제12화 만남", "1부"처럼 번호와 단위가 붙은 줄
/// - "Chapter 3", "프롤로그", "에필로그", "외전", "후기" 같은 낱말로 시작하는 줄
final _heading = RegExp(
  r'^\s*(?:'
  r'제\s*\d+\s*[장화회권부편막]'
  r'|\d+\s*[장화회권부편막](?=$|[\s.:\-—])'
  r'|chapter\s*\d+'
  r'|(?:프롤로그|에필로그|외전|서장|종장|후기|작가의\s*말|prologue|epilogue)(?=$|[\s.:\-—\d])'
  r')',
  caseSensitive: false,
);

/// 제목으로 보기엔 너무 긴 줄은 본문 문장으로 본다.
const _maxHeadingLength = 40;

/// txt 본문에서 장 제목 줄을 찾아 목차를 만든다.
/// 두 곳 이상 찾았을 때만 목차로 쓴다. 한 곳뿐이면 우연히 맞은 문장일 가능성이 높다.
List<TextTocEntry> detectTxtToc(String text) {
  final toc = <TextTocEntry>[];
  var lineStart = 0;
  while (lineStart < text.length) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = text.length;
    // 긴 줄은 정규식을 돌리기 전에 걸러 큰 파일에서도 빠르게 끝낸다.
    if (lineEnd - lineStart <= _maxHeadingLength * 2) {
      final line = text.substring(lineStart, lineEnd).trim();
      if (line.isNotEmpty && line.length <= _maxHeadingLength && _heading.hasMatch(line)) {
        toc.add(TextTocEntry(line, lineStart));
      }
    }
    lineStart = lineEnd + 1;
  }
  return toc.length < 2 ? const [] : toc;
}
