import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// zip 파일에서 항목 하나만 읽는다. 압축 해제가 화면을 멈추지 않도록 별도 isolate에서 돈다.
Future<Uint8List> readZipEntry(String zipPath, String name) {
  return Isolate.run(() {
    final input = InputFileStream(zipPath);
    try {
      final file = ZipDecoder().decodeStream(input).find(name);
      if (file == null) throw StateError('압축 파일에서 $name 을(를) 찾을 수 없습니다.');
      return file.content;
    } finally {
      input.closeSync();
    }
  });
}

/// zip 파일 안의 그림. Flutter 이미지 캐시가 디코딩 결과를 관리한다.
class ZipEntryImage extends ImageProvider<ZipEntryImage> {
  const ZipEntryImage(this.zipPath, this.name);

  final String zipPath;
  final String name;

  @override
  Future<ZipEntryImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(ZipEntryImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await readZipEntry(zipPath, name);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    return other is ZipEntryImage && other.zipPath == zipPath && other.name == name;
  }

  @override
  int get hashCode => Object.hash(zipPath, name);
}
