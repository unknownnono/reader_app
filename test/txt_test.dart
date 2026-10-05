import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/formats/txt/txt_decoder.dart';
import 'package:reader_app/formats/txt/txt_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeTxt', () {
    Future<String> neverCalled(String charset, Uint8List bytes) {
      fail('레거시 디코더가 호출되면 안 된다');
    }

    test('UTF-8과 BOM을 처리하고 줄바꿈을 통일한다', () async {
      final plain = Uint8List.fromList(utf8.encode('가나다\r\n라마바'));
      expect(await decodeTxt(plain, legacyDecoder: neverCalled), '가나다\n라마바');

      final withBom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('가나다')]);
      expect(await decodeTxt(withBom, legacyDecoder: neverCalled), '가나다');
    });

    test('UTF-16 LE BOM을 처리한다', () async {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x00, 0xAC, 0x41, 0x00]);
      expect(await decodeTxt(bytes, legacyDecoder: neverCalled), '가A');
    });

    test('UTF-8이 아니면 지원되는 한국어 인코딩 이름을 찾을 때까지 시도한다', () async {
      final tried = <String>[];
      // "가"의 CP949 바이트. UTF-8로는 잘못된 시퀀스다.
      final bytes = Uint8List.fromList([0xB0, 0xA1]);
      final text = await decodeTxt(
        bytes,
        legacyDecoder: (charset, bytes) async {
          tried.add(charset);
          if (charset != 'windows-949') throw Exception('unsupported');
          return '가';
        },
      );
      expect(text, '가');
      expect(tried.last, 'windows-949');
    });
  });

  group('TxtPaginator', () {
    final text = List.generate(
      300,
      (i) => i % 7 == 0 ? '' : '문단 $i: ${'가나다라마바사 ' * (i % 9 + 1)}',
    ).join('\n');
    const style = TextStyle(fontSize: 18, height: 1.7);
    const strut = StrutStyle(fontSize: 18, height: 1.7, forceStrutHeight: true);
    final paginator = TxtPaginator(
      text: text,
      style: style,
      strutStyle: strut,
      pageSize: const Size(320, 560),
    );

    double heightOf(String slice) {
      final painter = TextPainter(
        text: TextSpan(text: slice, style: style),
        strutStyle: strut,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 320);
      return painter.height;
    }

    test('앞으로 넘기면 빠지는 글자 없이 끝까지 가고 각 페이지는 화면에 들어간다', () {
      final starts = <int>[0];
      while (starts.last < text.length) {
        final end = paginator.pageEnd(starts.last);
        expect(end, greaterThan(starts.last));
        var page = text.substring(starts.last, end);
        if (page.endsWith('\n')) page = page.substring(0, page.length - 1);
        expect(heightOf(page), lessThanOrEqualTo(560.5));
        starts.add(end);
      }
      expect(starts.length, greaterThan(5));
    });

    test('뒤로 넘긴 페이지는 화면에 들어가고 현재 위치 바로 앞에서 끝난다', () {
      var end = text.length;
      var pages = 0;
      while (end > 0) {
        final start = paginator.pageStartBefore(end);
        expect(start, lessThan(end));
        var page = text.substring(start, end);
        if (page.endsWith('\n')) page = page.substring(0, page.length - 1);
        expect(heightOf(page), lessThanOrEqualTo(560.5));
        end = start;
        pages++;
      }
      expect(pages, greaterThan(5));
    });
  });
}
