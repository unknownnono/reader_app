import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const databaseFileName = 'reader_app.sqlite';

/// SQLite가 본 파일 옆에 두는 파일들. 본 파일과 항상 같이 움직여야 한다.
const _databaseSiblings = ['-wal', '-shm', '-journal'];

/// 앱이 쓰는 두 폴더.
class StorageLocations {
  const StorageLocations({required this.inbox, required this.data});

  /// 사용자가 파일 앱으로 책을 넣는 폴더(앱 문서 폴더). 파일 앱에 보인다.
  final Directory inbox;

  /// 서재 저장소와 가져온 책을 두는 폴더. 파일 앱에 보이지 않아 실수로 지울 일이 없다.
  final Directory data;
}

/// 앱이 쓸 폴더를 정한다.
///
/// 예전 버전은 저장소와 책을 문서 폴더에 두어 파일 앱에서 보였다. 그 자료가 남아 있으면
/// 보이지 않는 폴더로 옮긴다. 옮기다 실패하면 옮긴 것을 되돌리고 예전 자리를 그대로 쓴다.
Future<StorageLocations> resolveStorage({
  Future<Directory> Function() documents = getApplicationDocumentsDirectory,
  Future<Directory> Function() support = getApplicationSupportDirectory,
}) async {
  final docs = await documents();
  final Directory data;
  try {
    data = await support();
    await data.create(recursive: true);
  } on Object {
    return StorageLocations(inbox: docs, data: docs);
  }

  final oldDatabase = File(p.join(docs.path, databaseFileName));
  final newDatabase = File(p.join(data.path, databaseFileName));
  final oldBooks = Directory(p.join(docs.path, 'books'));
  final newBooks = Directory(p.join(data.path, 'books'));
  // 이미 옮겼거나 처음 설치한 경우에는 옮길 것이 없다.
  if (await newDatabase.exists() || !await oldDatabase.exists()) {
    // 저장소만 새 자리에 있고 책 폴더가 예전 자리에 남았다면 마저 옮긴다.
    if (await newDatabase.exists() && await oldBooks.exists() && !await newBooks.exists()) {
      try {
        await oldBooks.rename(newBooks.path);
      } on Object {
        // 못 옮기면 그 책들은 열리지 않지만, 서재 목록은 지켜야 하므로 새 자리를 계속 쓴다.
      }
    }
    return StorageLocations(inbox: docs, data: data);
  }

  final moved = <(String from, String to)>[];
  try {
    if (await oldBooks.exists()) {
      // 비어 있는 폴더가 먼저 생겨 있었다면 치우고, 내용이 있으면 덮어쓰지 않고 그만둔다.
      if (await newBooks.exists()) await newBooks.delete();
      await oldBooks.rename(newBooks.path);
      moved.add((oldBooks.path, newBooks.path));
    }
    for (final suffix in [..._databaseSiblings, '']) {
      final from = File('${oldDatabase.path}$suffix');
      if (!await from.exists()) continue;
      final to = '${newDatabase.path}$suffix';
      await from.rename(to);
      moved.add((from.path, to));
    }
    return StorageLocations(inbox: docs, data: data);
  } on Object {
    for (final (from, to) in moved.reversed) {
      try {
        await FileSystemEntity.isDirectory(to)
            ? await Directory(to).rename(from)
            : await File(to).rename(from);
      } on Object {
        // 되돌리지 못한 항목은 다음 실행에서 다시 옮기기를 시도한다.
      }
    }
    return StorageLocations(inbox: docs, data: docs);
  }
}
