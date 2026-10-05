import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/formats/epub/epub_parser.dart';
import 'package:reader_app/formats/text_content.dart';
import 'package:reader_app/formats/zip_entry.dart';

import 'support/sample_epub.dart';

void main() {
  test('문단은 줄바꿈으로, 제목 뒤에는 빈 줄을 두고 꾸밈과 스크립트는 뺀다', () {
    final text = htmlToText('''
<html><head><title>무시</title><style>p{}</style></head>
<body><h2>제목</h2><p>첫   문단</p><p>둘째<br/>줄</p><p>&nbsp;</p><p>셋째</p>
<script>x()</script></body></html>''');
    expect(text, '제목\n\n첫 문단\n둘째\n줄\n\n셋째');
  });

  for (final useNav in [false, true]) {
    test('epub 본문을 순서대로 잇고 목차 위치를 찾는다 (${useNav ? 'EPUB 3 nav' : 'NCX'})', () async {
      final dir = await Directory.systemTemp.createTemp('epub_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'sample.epub'));
      await file.writeAsBytes(buildSampleEpub(useNav: useNav));

      final content = await loadEpub(file.path);
      expect(
        content.text,
        '제1장 시작\n\n첫 문단입니다.\n둘째 문단&기호\n줄바꿈'
        '\n\n'
        '제2장 끝\n\n마지막 문단입니다.\n$imagePlaceholder\n$imagePlaceholder',
      );
      // 그림 자리마다 책 안의 그림 경로가 연결된다. 없는 그림은 자리도 만들지 않는다.
      final picOffset = content.text.indexOf(imagePlaceholder);
      expect(content.images, {
        picOffset: 'OEBPS/images/pic.png',
        picOffset + 2: 'OEBPS/images/cover.png',
      });
      expect(await readZipEntry(file.path, content.images[picOffset]!), samplePng);
      expect(content.toc.map((e) => e.title), ['제1장 시작', '제2장 끝']);
      expect(content.toc[0].offset, 0);
      expect(content.text.substring(content.toc[1].offset), startsWith('제2장 끝'));
    });
  }

  test('epub이 아닌 파일은 알아볼 수 있는 오류를 낸다', () async {
    final dir = await Directory.systemTemp.createTemp('epub_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'broken.epub'));
    await file.writeAsBytes([1, 2, 3]);
    expect(() => parseEpub(file.path), throwsA(anything));
  });
}
