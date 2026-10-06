import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'transfer_page.dart';

/// 같은 Wi-Fi의 PC 브라우저에서 파일을 받아 앱 폴더에 저장하는 작은 웹 서버.
///
/// 브라우저는 파일 하나마다 `POST /upload?path=폴더/파일이름`으로 내용을 그대로 보내고,
/// 다 보내면 `POST /done`을 부른다. 받은 파일을 책으로 가져오는 일은 [onBatchDone]이 맡는다.
class TransferServer {
  TransferServer({
    required this.inbox,
    required this.onFileReceived,
    required this.onBatchDone,
  });

  static const preferredPort = 8080;

  /// 받은 파일을 둘 폴더(앱 문서 폴더)
  final Directory inbox;
  final void Function(String relativePath) onFileReceived;

  /// 한 묶음을 다 받았을 때 부른다. 가져온 책 수를 돌려준다.
  final Future<int> Function() onBatchDone;

  HttpServer? _server;

  int? get port => _server?.port;

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      // 다른 앱이 쓰고 있으면 비어 있는 번호를 받는다.
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/') {
        response.headers.contentType = ContentType.html;
        response.write(transferPageHtml);
      } else if (request.method == 'POST' && path == '/upload') {
        final relative = safeRelativePath(request.uri.queryParameters['path'] ?? '');
        if (relative == null) {
          response.statusCode = HttpStatus.badRequest;
          response.write('잘못된 파일 이름입니다.');
        } else {
          await _save(request, relative);
          onFileReceived(relative);
          response.write('ok');
        }
      } else if (request.method == 'POST' && path == '/done') {
        await request.drain<void>();
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'imported': await onBatchDone()}));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (error) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('$error');
    } finally {
      await response.close();
    }
  }

  /// 다 받기 전에는 `.part`를 붙인 이름으로 써서, 받는 도중의 파일이 책으로 잡히지 않게 한다.
  Future<void> _save(HttpRequest request, String relative) async {
    final target = File(p.joinAll([inbox.path, ...relative.split('/')]));
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    try {
      await request.cast<List<int>>().pipe(partial.openWrite());
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}

final _invalidSegmentChars = RegExp(r'[<>:"|?*\x00-\x1f]');

/// 브라우저가 보낸 경로를 앱 폴더 안의 안전한 상대 경로로 바꾼다. 쓸 수 없으면 null.
///
/// 폴더를 거슬러 올라가는 `..`와 숨김 파일, 앱이 직접 쓰는 `books` 폴더는 받지 않는다.
String? safeRelativePath(String raw) {
  final segments = <String>[];
  for (final part in raw.split(RegExp(r'[/\\]'))) {
    final segment = part.replaceAll(_invalidSegmentChars, '_').trim();
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..' || segment.startsWith('.')) return null;
    segments.add(segment);
  }
  if (segments.isEmpty || segments.first == 'books') return null;
  return segments.join('/');
}

/// PC에서 접속할 주소들. Wi-Fi에 연결되어 있지 않으면 비어 있다.
Future<List<String>> transferAddresses(int port) async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (!address.isLoopback && !address.isLinkLocal) 'http://${address.address}:$port',
  ];
}
