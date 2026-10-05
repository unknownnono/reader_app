import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:reader_app/app/app.dart';
import 'package:reader_app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/sample_epub.dart';

/// 실제 기기/시뮬레이터에서 앱을 띄워 확인한다.
/// 앱 폴더에 넣은 만화 폴더와 CP949 txt가 서재에 들어오고 열리는지 본다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        // 화면 전환 애니메이션 중에는 탭이 무시되므로 끝날 때까지 기다린다.
        await tester.pump(const Duration(milliseconds: 600));
        return;
      }
    }
    fail('시간 안에 나타나지 않음: $finder');
  }

  // 표지 자리에도 제목이 적히므로 책 항목의 제목 글자(마지막 것)를 고른다.
  Finder bookTitle(String title) => find.text(title).last;

  Future<List<int>> pngPage(int number) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 300),
      Paint()..color = Color.fromARGB(255, 40 * number, 120, 200),
    );
    final image = await recorder.endRecording().toImage(200, 300);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  testWidgets('앱 폴더에 넣은 만화 폴더와 CP949 txt를 가져와 연다', (tester) async {
    // 매번 다른 이름을 써서 이전 실행이 남긴 책과 섞이지 않게 한다.
    final tag = DateTime.now().millisecondsSinceEpoch % 100000;
    final comicTitle = '시험만화 $tag';
    final novelTitle = '시험소설 $tag';

    final docs = await getApplicationDocumentsDirectory();
    final comicDir = Directory(p.join(docs.path, comicTitle));
    await comicDir.create(recursive: true);
    for (final number in [1, 2, 10]) {
      await File(p.join(comicDir.path, '$number.png'))
          .writeAsBytes(await tester.runAsync(() => pngPage(number)) as List<int>);
    }
    // "가나다라"의 CP949 바이트. UTF-8로는 읽히지 않는다.
    await File(p.join(docs.path, '$novelTitle.txt'))
        .writeAsBytes([0xB0, 0xA1, 0xB3, 0xAA, 0xB4, 0xD9, 0xB6, 0xF3]);

    final epubTitle = '시험전자책 $tag';
    await File(p.join(docs.path, '$epubTitle.epub')).writeAsBytes(buildSampleEpub());

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ReaderApp(),
      ),
    );
    await pumpUntil(tester, find.text('앱 폴더에서 3권을 추가했습니다.'));
    // 가져온 것은 앱 폴더에서 books로 옮겨진다.
    expect(await comicDir.exists(), isFalse);

    // CP949 txt가 한글로 열린다. 서재에 책이 많으면 화면 밖에 있을 수 있어 스크롤해서 찾는다.
    await tester.scrollUntilVisible(bookTitle(novelTitle), 300);
    await tester.tap(bookTitle(novelTitle));
    await pumpUntil(tester, find.textContaining('가나다라', findRichText: true));
    // 메뉴를 띄운다.
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first));
    await pumpUntil(tester, find.byType(BackButton));

    // 읽기 설정을 바꾸면 바로 기기에 저장된다. 확인 뒤 원래대로 돌려놓는다.
    await tester.tap(find.byTooltip('읽기 설정'));
    await pumpUntil(tester, find.text('세피아'));
    await tester.tap(find.text('세피아'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(prefs.getString('reader.theme'), 'sepia');
    await tester.tap(find.text('자동'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(prefs.getString('reader.theme'), 'system');
    // 설정 창 바깥을 눌러 닫는다.
    await tester.tapAt(const Offset(30, 200));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text('서재'));

    // epub 본문이 열리고, 목차로 2장으로 이동할 수 있다.
    await tester.scrollUntilVisible(bookTitle(epubTitle), 300);
    await tester.tap(bookTitle(epubTitle));
    await pumpUntil(tester, find.textContaining('첫 문단입니다.', findRichText: true));
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first));
    await pumpUntil(tester, find.byTooltip('목차'));
    await tester.tap(find.byTooltip('목차'));
    await pumpUntil(tester, find.text('제2장 끝'));
    await tester.tap(find.text('제2장 끝'));
    await pumpUntil(tester, find.textContaining('마지막 문단입니다.', findRichText: true));
    expect(find.textContaining('첫 문단입니다.', findRichText: true), findsNothing);
    // 다음 페이지는 삽화다. 그림이 실제로 디코딩되어 그려지는지 본다.
    final page = tester.getRect(find.byType(Scaffold).first);
    await tester.tapAt(Offset(page.right - 20, page.center.dy));
    final illustration = find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null,
    );
    await pumpUntil(tester, illustration);
    expect(find.text('그림을 표시할 수 없습니다.'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first));
    await pumpUntil(tester, find.byType(BackButton));
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text('서재'));

    // 만화가 열리고 쪽수가 맞다.
    await tester.scrollUntilVisible(bookTitle(comicTitle), 300);
    await tester.tap(bookTitle(comicTitle));
    await pumpUntil(tester, find.byType(PhotoViewGallery));
    expect(find.textContaining('파일을 열지 못했습니다'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PhotoViewGallery)));
    await pumpUntil(tester, find.text('1 / 3'));
  });
}
