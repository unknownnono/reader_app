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

    await tester.pumpWidget(const ProviderScope(child: ReaderApp()));
    await pumpUntil(tester, find.text('앱 폴더에서 2권을 추가했습니다.'));
    // 가져온 것은 앱 폴더에서 books로 옮겨진다.
    expect(await comicDir.exists(), isFalse);

    // CP949 txt가 한글로 열린다. 서재에 책이 많으면 화면 밖에 있을 수 있어 스크롤해서 찾는다.
    await tester.scrollUntilVisible(find.text(novelTitle), 300);
    await tester.tap(find.text(novelTitle));
    await pumpUntil(tester, find.textContaining('가나다라', findRichText: true));
    // 메뉴를 띄워 뒤로 간다.
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).first));
    await pumpUntil(tester, find.byType(BackButton));
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text('서재'));

    // 만화가 열리고 쪽수가 맞다.
    await tester.scrollUntilVisible(find.text(comicTitle), 300);
    await tester.tap(find.text(comicTitle));
    await pumpUntil(tester, find.byType(PhotoViewGallery));
    expect(find.textContaining('파일을 열지 못했습니다'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PhotoViewGallery)));
    await pumpUntil(tester, find.text('1 / 3'));
  });
}
