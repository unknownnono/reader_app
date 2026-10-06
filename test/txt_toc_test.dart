import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/formats/txt/txt_toc.dart';

void main() {
  test('장 제목 줄을 찾아 그 줄의 시작 위치와 함께 돌려준다', () {
    const text = '프롤로그\n'
        '옛날 옛적에 1화 분량의 이야기가 있었다.\n'
        '\n'
        '제 1 장 만남\n'
        '그는 길을 걸었다.\n'
        '  2화. 헤어짐\n'
        '그녀는 떠났다.\n'
        'Chapter 3\n'
        '끝.\n'
        '외전 1\n'
        '뒷이야기.\n';
    final toc = detectTxtToc(text);
    expect(toc.map((e) => e.title), ['프롤로그', '제 1 장 만남', '2화. 헤어짐', 'Chapter 3', '외전 1']);
    for (final entry in toc) {
      expect(text.substring(entry.offset).trimLeft(), startsWith(entry.title));
    }
  });

  test('본문 문장은 제목으로 보지 않는다', () {
    const text = '제 1 장\n'
        '1화를 다 보고 나서야 그는 잠이 들었다. 그리고 다음 날 아침이 될 때까지 깨지 않았다.\n'
        '2화가 방영되던 날이었다 그리고 이 줄은 제목이라기에는 지나치게 길어서 본문으로 보아야 한다.\n'
        '10장의 사진을 찍었다.\n'
        '후기를 남겼다.\n'
        '제 2 장\n';
    expect(detectTxtToc(text).map((e) => e.title), ['제 1 장', '제 2 장']);
  });

  test('제목이 하나뿐이면 목차를 만들지 않는다', () {
    expect(detectTxtToc('제 1 장\n내용뿐인 글.\n'), isEmpty);
    expect(detectTxtToc('목차가 없는 글.\n그냥 이어진다.\n'), isEmpty);
  });
}
