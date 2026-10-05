import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/data/settings_repository.dart';
import 'package:reader_app/domain/reader_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('저장한 설정을 다시 불러온다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepository(prefs);
    expect(repository.load().fontSize, 18);

    await repository.save(
      const ReaderSettings(
        fontSize: 24,
        lineHeight: 2.0,
        margin: 32,
        theme: ReaderTheme.sepia,
        comicRightToLeft: true,
      ),
    );
    final loaded = SettingsRepository(prefs).load();
    expect(loaded.fontSize, 24);
    expect(loaded.lineHeight, 2.0);
    expect(loaded.margin, 32);
    expect(loaded.theme, ReaderTheme.sepia);
    expect(loaded.comicRightToLeft, isTrue);
  });

  test('범위를 벗어났거나 알 수 없는 저장값은 안전한 값으로 바꾼다', () async {
    SharedPreferences.setMockInitialValues({
      'reader.fontSize': 500.0,
      'reader.theme': 'neon',
    });
    final loaded = SettingsRepository(await SharedPreferences.getInstance()).load();
    expect(loaded.fontSize, ReaderSettings.maxFontSize);
    expect(loaded.theme, ReaderTheme.system);
  });

  test('저장소가 없으면 기본값을 쓰고 저장은 조용히 넘어간다', () async {
    final repository = SettingsRepository(null);
    expect(repository.load().theme, ReaderTheme.system);
    await repository.save(const ReaderSettings(fontSize: 30));
  });
}
