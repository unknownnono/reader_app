import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reader_settings.dart';

/// 읽기 설정을 기기에 저장하고 불러온다.
/// [_prefs]가 없으면(테스트 등) 저장하지 않고 기본값만 돌려준다.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences? _prefs;

  ReaderSettings load() {
    final prefs = _prefs;
    if (prefs == null) return const ReaderSettings();
    final themeName = prefs.getString('reader.theme');
    // copyWith를 거쳐 저장된 값이 허용 범위를 벗어나지 않게 한다.
    return const ReaderSettings().copyWith(
      fontSize: prefs.getDouble('reader.fontSize'),
      lineHeight: prefs.getDouble('reader.lineHeight'),
      margin: prefs.getDouble('reader.margin'),
      theme: ReaderTheme.values.where((t) => t.name == themeName).firstOrNull,
      comicRightToLeft: prefs.getBool('comic.rightToLeft'),
      comicMode: ComicMode.values
          .where((m) => m.name == prefs.getString('comic.mode'))
          .firstOrNull,
      comicDoublePage: prefs.getBool('comic.doublePage'),
      libraryGrid: prefs.getBool('library.grid'),
      librarySort: LibrarySort.values
          .where((s) => s.name == prefs.getString('library.sort'))
          .firstOrNull,
    );
  }

  Future<void> save(ReaderSettings settings) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setDouble('reader.fontSize', settings.fontSize);
    await prefs.setDouble('reader.lineHeight', settings.lineHeight);
    await prefs.setDouble('reader.margin', settings.margin);
    await prefs.setString('reader.theme', settings.theme.name);
    await prefs.setBool('comic.rightToLeft', settings.comicRightToLeft);
    await prefs.setString('comic.mode', settings.comicMode.name);
    await prefs.setBool('comic.doublePage', settings.comicDoublePage);
    await prefs.setBool('library.grid', settings.libraryGrid);
    await prefs.setString('library.sort', settings.librarySort.name);
  }
}
