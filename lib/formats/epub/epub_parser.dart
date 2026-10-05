import 'dart:convert';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../text_content.dart';

const _blockTags = {
  'p', 'div', 'section', 'article', 'blockquote', 'li', 'ul', 'ol', 'tr', 'table',
  'dt', 'dd', 'pre', 'hr', 'header', 'footer', 'aside', 'figure', 'figcaption',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
};
const _headingTags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};
const _skippedTags = {'script', 'style', 'head', 'svg', 'math'};

final _posix = p.posix;

/// epub을 읽어 본문 전체를 하나의 텍스트로 만든다.
/// 글자만 뽑아내므로 그림과 글꼴·색 같은 꾸밈은 빠진다.
Future<TextContent> loadEpub(String path) {
  return Isolate.run(() => parseEpub(path));
}

TextContent parseEpub(String path) {
  final input = InputFileStream(path);
  try {
    return _parse(ZipDecoder().decodeStream(input));
  } finally {
    input.closeSync();
  }
}

TextContent _parse(Archive archive) {
  String read(String name) {
    final file = archive.find(name);
    if (file == null) throw FormatException('epub 안에 $name 이(가) 없습니다.');
    return utf8.decode(file.content, allowMalformed: true);
  }

  final container = XmlDocument.parse(read('META-INF/container.xml'));
  final opfPath = container.descendantElements
      .firstWhere(
        (e) => e.localName == 'rootfile',
        orElse: () => throw const FormatException('epub 구성 파일을 찾을 수 없습니다.'),
      )
      .getAttribute('full-path')!;
  final opfDir = _posix.dirname(opfPath);
  final opf = XmlDocument.parse(read(opfPath));

  // 목록(manifest)의 id → 압축 파일 안 경로
  final items = <String, XmlElement>{
    for (final item in opf.descendantElements.where((e) => e.localName == 'item'))
      if (item.getAttribute('id') != null) item.getAttribute('id')!: item,
  };
  String pathOf(XmlElement item) => _resolve(opfDir, item.getAttribute('href') ?? '');

  // 읽는 순서(spine)대로 본문을 이어 붙이고 각 장의 시작 위치를 기억한다.
  final buffer = StringBuffer();
  final chapterOffsets = <String, int>{};
  final spine = opf.descendantElements.firstWhere((e) => e.localName == 'spine');
  for (final ref in spine.childElements.where((e) => e.localName == 'itemref')) {
    final item = items[ref.getAttribute('idref')];
    if (item == null) continue;
    final chapterPath = pathOf(item);
    if (archive.find(chapterPath) == null) continue;
    final text = htmlToText(read(chapterPath));
    if (buffer.isNotEmpty) buffer.write('\n\n');
    chapterOffsets[chapterPath] = buffer.length;
    buffer.write(text);
  }

  final toc = <TextTocEntry>[];
  void addEntry(String title, String href, String baseDir) {
    final target = _resolve(baseDir, href.split('#').first);
    final offset = chapterOffsets[target];
    final label = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (offset == null || label.isEmpty) return;
    // 한 장 안의 여러 소제목은 같은 위치를 가리키므로 첫 항목만 남긴다.
    if (toc.isNotEmpty && toc.last.offset == offset) return;
    toc.add(TextTocEntry(label, offset));
  }

  // EPUB 3의 nav 문서를 먼저 보고, 없으면 EPUB 2의 NCX를 쓴다.
  final navItem = items.values.cast<XmlElement?>().firstWhere(
        (e) => (e!.getAttribute('properties') ?? '').split(' ').contains('nav'),
        orElse: () => null,
      );
  if (navItem != null && archive.find(pathOf(navItem)) != null) {
    final navPath = pathOf(navItem);
    for (final link in html.parse(read(navPath)).querySelectorAll('nav a[href]')) {
      addEntry(link.text, link.attributes['href']!, _posix.dirname(navPath));
    }
  }
  if (toc.isEmpty) {
    final ncxItem = items[spine.getAttribute('toc')] ??
        items.values.cast<XmlElement?>().firstWhere(
              (e) => e!.getAttribute('media-type') == 'application/x-dtbncx+xml',
              orElse: () => null,
            );
    if (ncxItem != null && archive.find(pathOf(ncxItem)) != null) {
      final ncxPath = pathOf(ncxItem);
      final ncx = XmlDocument.parse(read(ncxPath));
      for (final point in ncx.descendantElements.where((e) => e.localName == 'navPoint')) {
        final label = point.childElements
            .where((e) => e.localName == 'navLabel')
            .map((e) => e.innerText)
            .firstOrNull;
        final src = point.childElements
            .where((e) => e.localName == 'content')
            .map((e) => e.getAttribute('src'))
            .firstOrNull;
        if (label != null && src != null) {
          addEntry(label, src, _posix.dirname(ncxPath));
        }
      }
    }
  }

  return TextContent(buffer.toString(), toc: toc);
}

/// [href]를 [baseDir] 기준 압축 파일 안 경로로 바꾼다. "%20" 같은 URL 인코딩도 푼다.
String _resolve(String baseDir, String href) {
  final decoded = Uri.decodeFull(href);
  return _posix.normalize(baseDir == '.' ? decoded : _posix.join(baseDir, decoded));
}

/// XHTML 한 장을 읽기용 텍스트로 바꾼다. 문단은 줄바꿈으로, 제목 뒤에는 빈 줄을 둔다.
String htmlToText(String source) {
  final document = html.parse(source);
  final out = StringBuffer();
  var endsWithNewline = true;

  void write(String text) {
    if (text.isEmpty) return;
    out.write(text);
    endsWithNewline = text.endsWith('\n');
  }

  void breakLine() {
    if (!endsWithNewline) write('\n');
  }

  void walk(dom.Node node) {
    if (node is dom.Text) {
      // 소스의 줄바꿈과 들여쓰기는 의미가 없으므로 공백 하나로 줄이고, 줄 맨 앞에서는 버린다.
      // &nbsp;는 일부러 넣은 빈 문단일 수 있어 그대로 둔다.
      var text = node.text.replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ');
      if (endsWithNewline && text.startsWith(' ')) text = text.substring(1);
      write(text);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (_skippedTags.contains(tag)) return;
    if (tag == 'br') {
      write('\n');
      return;
    }
    final isBlock = _blockTags.contains(tag);
    if (isBlock) breakLine();
    node.nodes.forEach(walk);
    if (isBlock) breakLine();
    if (_headingTags.contains(tag)) write('\n');
  }

  walk(document.body ?? document.documentElement!);

  // 줄 앞뒤 공백을 지우고, 빈 줄이 여러 개 이어지면 하나로 줄인다.
  final lines = <String>[];
  for (final raw in out.toString().split('\n')) {
    final line = raw.trim();
    if (line.isEmpty && (lines.isEmpty || lines.last.isEmpty)) continue;
    lines.add(line);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}
