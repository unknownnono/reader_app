import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 8×12 크기의 단색 PNG 그림. 실제로 디코딩되는 파일이어야 해서 규격대로 직접 만든다.
final Uint8List samplePng = _buildPng(width: 8, height: 12);

Uint8List _buildPng({required int width, required int height}) {
  Uint8List chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    final bytes = ByteData(4);
    final out = BytesBuilder();
    bytes.setUint32(0, data.length);
    out.add(bytes.buffer.asUint8List().toList());
    out.add(body);
    bytes.setUint32(0, getCrc32(body));
    out.add(bytes.buffer.asUint8List().toList());
    return out.toBytes();
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // 채널당 8비트
    ..setUint8(9, 2); // RGB
  // 각 줄은 필터 종류(0) 한 바이트 뒤에 픽셀이 온다.
  final row = [0, for (var x = 0; x < width; x++) ...[40, 120, 200]];
  final pixels = [for (var y = 0; y < height; y++) ...row];
  return Uint8List.fromList([
    ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ...chunk('IHDR', header.buffer.asUint8List()),
    ...chunk('IDAT', zlib.encode(pixels)),
    ...chunk('IEND', const []),
  ]);
}

/// 시험용 epub 파일 바이트를 만든다. 장 2개와 목차(NCX 또는 EPUB 3 nav)를 가진다.
Uint8List buildSampleEpub({bool useNav = false}) {
  ArchiveFile text(String name, String content) {
    return ArchiveFile.bytes(name, utf8.encode(content));
  }

  String chapter(String title, String body) => '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>$title</title><style>p { color: red; }</style></head>
<body>
  <h1>$title</h1>
  $body
</body>
</html>''';

  final archive = Archive()
    ..addFile(text('mimetype', 'application/epub+zip'))
    ..addFile(text('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''))
    ..addFile(text('OEBPS/content.opf', '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="${useNav ? '3.0' : '2.0'}">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>시험 소설</dc:title>
    ${useNav ? '' : '<meta name="cover" content="cover-img"/>'}
  </metadata>
  <manifest>
    <item id="pic" href="images/pic.png" media-type="image/png"/>
    <item id="cover-img" href="images/cover.png" media-type="image/png"${useNav ? ' properties="cover-image"' : ''}/>
    <item id="ch1" href="text/ch%201.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>
    ${useNav ? '<item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/>' : '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'}
  </manifest>
  <spine${useNav ? '' : ' toc="ncx"'}>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>'''))
    ..addFile(text(
      'OEBPS/text/ch 1.xhtml',
      chapter('제1장 시작', '<p>첫 문단입니다.</p>\n<p>둘째   문단&amp;기호<br/>줄바꿈</p>'),
    ))
    ..addFile(text(
      'OEBPS/text/ch2.xhtml',
      chapter(
        '제2장 끝',
        '<div><p>마지막 문단입니다.</p></div><script>alert(1)</script>'
            '<p><img src="../images/pic.png" alt="삽화"/></p>'
            '<p><img src="../images/missing.png"/></p>'
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
            '<image xlink:href="../images/cover.png"/></svg>',
      ),
    ))
    ..addFile(ArchiveFile.bytes('OEBPS/images/pic.png', samplePng))
    ..addFile(ArchiveFile.bytes('OEBPS/images/cover.png', samplePng));
  if (useNav) {
    archive.addFile(text('OEBPS/nav.xhtml', '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body><nav epub:type="toc"><ol>
  <li><a href="text/ch%201.xhtml">제1장 시작</a></li>
  <li><a href="text/ch2.xhtml#top">제2장 끝</a></li>
</ol></nav></body></html>'''));
  } else {
    archive.addFile(text('OEBPS/toc.ncx', '''
<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="n1"><navLabel><text>제1장 시작</text></navLabel><content src="text/ch%201.xhtml"/></navPoint>
    <navPoint id="n2"><navLabel><text>제2장 끝</text></navLabel><content src="text/ch2.xhtml#top"/></navPoint>
  </navMap>
</ncx>'''));
  }
  return ZipEncoder().encodeBytes(archive);
}
