import 'package:flutter/material.dart';

/// 탭 첫 화면의 큰 제목. 아이폰 기본 앱처럼 왼쪽에 굵게 둔다.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700));
  }
}

/// 아이폰 기본 앱과 비슷한 차림. 흰색·검정 바탕에 파란 강조색 하나만 쓴다.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final accent = dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  // 설정 화면처럼 묶음이 놓이는 바탕과, 그 위에 뜨는 판의 색
  final grouped = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  final raised = dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  final separator = dark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    error: dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
    onError: Colors.white,
    surface: dark ? Colors.black : Colors.white,
    onSurface: dark ? Colors.white : Colors.black,
    onSurfaceVariant: const Color(0xFF8E8E93),
    surfaceContainerLowest: dark ? Colors.black : Colors.white,
    surfaceContainerLow: grouped,
    surfaceContainer: grouped,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: raised,
    outline: separator,
    outlineVariant: separator,
    secondaryContainer: dark ? const Color(0xFF0A3A66) : const Color(0xFFDCEBFF),
    onSecondaryContainer: dark ? Colors.white : Colors.black,
    // 본문 검색에서 찾은 말에 칠하는 색
    tertiaryContainer: dark ? const Color(0xFF665200) : const Color(0xFFFFE08A),
    onTertiaryContainer: dark ? Colors.white : Colors.black,
  );

  return ThemeData(
    colorScheme: scheme,
    // 안드로이드에서도 같은 모양과 동작(뒤로 밀기, 스위치 모양 등)을 쓴다.
    platform: TargetPlatform.iOS,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      actionsIconTheme: IconThemeData(color: accent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: grouped,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: separator, thickness: 0.5, space: 0.5),
    listTileTheme: ListTileThemeData(iconColor: accent),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? raised : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
  );
}
