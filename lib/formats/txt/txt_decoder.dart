import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

/// 플랫폼 변환기로 [charset] 디코딩을 시도한다. 지원하지 않는 이름이면 예외를 던진다.
typedef LegacyDecoder = Future<String> Function(String charset, Uint8List bytes);

/// CP949 이름은 플랫폼마다 달라서(Android는 Java, iOS는 IANA 이름) 순서대로 시도한다.
/// 'cp949'는 Java에서 IBM-949를 뜻하므로 Windows 계열 이름을 먼저 둔다.
const _koreanCharsets = ['x-windows-949', 'ms949', 'windows-949', 'cp949', 'EUC-KR'];

/// txt 파일 바이트를 문자열로 바꾼다.
/// BOM → UTF-8 → CP949 순으로 판별하고, 줄바꿈은 \n으로 통일한다.
Future<String> decodeTxt(
  Uint8List bytes, {
  LegacyDecoder legacyDecoder = CharsetConverter.decode,
}) async {
  return _normalizeNewlines(await _decode(bytes, legacyDecoder));
}

Future<String> _decode(Uint8List bytes, LegacyDecoder legacyDecoder) async {
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(Uint8List.sublistView(bytes, 3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes, Endian.little);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes, Endian.big);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // UTF-8이 아니면 한국어 레거시 인코딩으로 본다.
  }
  for (final charset in _koreanCharsets) {
    try {
      return await legacyDecoder(charset, bytes);
    } catch (_) {
      continue;
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _decodeUtf16(Uint8List bytes, Endian endian) {
  final data = ByteData.sublistView(bytes, 2);
  final units = Uint16List(data.lengthInBytes ~/ 2);
  for (var i = 0; i < units.length; i++) {
    units[i] = data.getUint16(i * 2, endian);
  }
  return String.fromCharCodes(units);
}

String _normalizeNewlines(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
