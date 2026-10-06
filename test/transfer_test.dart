import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_app/features/transfer/transfer_server.dart';

void main() {
  test('안전한 상대 경로만 받는다', () {
    expect(safeRelativePath('짱 01/01-001.jpg'), '짱 01/01-001.jpg');
    expect(safeRelativePath(r'C:\만화\짱 01\1.jpg'), 'C_/만화/짱 01/1.jpg');
    expect(safeRelativePath('/소설.txt'), '소설.txt');
    expect(safeRelativePath('../밖으로.txt'), isNull);
    expect(safeRelativePath('a/../../b.txt'), isNull);
    expect(safeRelativePath('.숨김'), isNull);
    expect(safeRelativePath('books/남의 책.txt'), isNull);
    expect(safeRelativePath(''), isNull);
  });

  group('TransferServer', () {
    late Directory inbox;
    late TransferServer server;
    late HttpClient client;
    final received = <String>[];
    var batches = 0;

    setUp(() async {
      inbox = await Directory.systemTemp.createTemp('transfer_test');
      received.clear();
      batches = 0;
      server = TransferServer(
        inbox: inbox,
        onFileReceived: received.add,
        onBatchDone: () async {
          batches++;
          return received.length;
        },
      );
      await server.start();
      client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.stop();
        await inbox.delete(recursive: true);
      });
    });

    Future<(int, String)> send(String method, String path, [List<int> body = const []]) async {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${server.port}$path'),
      );
      request.add(body);
      final response = await request.close();
      return (response.statusCode, await utf8.decodeStream(response));
    }

    test('올리기 화면을 내려 준다', () async {
      final (status, body) = await send('GET', '/');
      expect(status, 200);
      expect(body, contains('<title>ebook·comics viewer로 보내기</title>'));
    });

    test('폴더째 올린 파일을 같은 구조로 저장하고, 다 받으면 가져오기를 부른다', () async {
      final path = Uri.encodeQueryComponent('짱 01/01-001.jpg');
      final (status, _) = await send('POST', '/upload?path=$path', [1, 2, 3]);
      expect(status, 200);
      expect(await File(p.join(inbox.path, '짱 01', '01-001.jpg')).readAsBytes(), [1, 2, 3]);
      expect(received, ['짱 01/01-001.jpg']);
      // 받는 도중에 쓰던 임시 파일은 남지 않는다.
      expect(
        await Directory(p.join(inbox.path, '짱 01')).list().map((e) => p.basename(e.path)).toList(),
        ['01-001.jpg'],
      );

      final (doneStatus, doneBody) = await send('POST', '/done');
      expect(doneStatus, 200);
      expect(jsonDecode(doneBody), {'imported': 1});
      expect(batches, 1);
    });

    test('앱 폴더 밖으로 나가는 경로는 거절하고 아무것도 쓰지 않는다', () async {
      final path = Uri.encodeQueryComponent('../밖으로.txt');
      final (status, _) = await send('POST', '/upload?path=$path', [1]);
      expect(status, 400);
      expect(await inbox.list().toList(), isEmpty);
      expect(await File(p.join(inbox.parent.path, '밖으로.txt')).exists(), isFalse);
    });

    test('같은 이름을 다시 올리면 새 내용으로 바꾼다', () async {
      await send('POST', '/upload?path=a.txt', [1]);
      await send('POST', '/upload?path=a.txt', [2, 2]);
      expect(await File(p.join(inbox.path, 'a.txt')).readAsBytes(), [2, 2]);
    });
  });
}
