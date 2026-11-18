import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chinese_font_library/chinese_font_library.dart';

const List<String> _webChineseFontFallback = <String>[
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'sans-serif',
];

/// 用枚举太麻烦了
enum ColorSeed {
  baseColor('M3 Baseline', Color(0xff6750a4)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, Color> colorSeedMap = {
  'M3 Baseline': Color(0xff6750a4),
  'Indigo': Colors.indigo,
  'Blue': Colors.blue,
  'Teal': Colors.teal,
  'Green': Colors.green,
  'Yellow': Colors.yellow,
  'Orange': Colors.orange,
  'Deep Orange': Colors.deepOrange,
  'Pink': Colors.pink,
};

const workbenchSeed = Color(0xff176b59);

final lightTheme = _buildTheme(Brightness.light);
final darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: workbenchSeed,
    brightness: brightness,
    primary: brightness == Brightness.light
        ? workbenchSeed
        : const Color(0xff8cdbc1),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: colors.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    textTheme: _buildTextTheme(brightness),
    scaffoldBackgroundColor: colors.surfaceContainerLow,
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    appBarTheme: AppBarThemeData(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 44),
      suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 44),
      errorMaxLines: 3,
      fillColor: colors.surfaceContainerLow,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(3),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
        shape: WidgetStatePropertyAll(menuShape),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: menuShape,
      position: PopupMenuPosition.under,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.primaryContainer,
        selectedForegroundColor: colors.onPrimaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
    ),
  );
}

TextTheme _buildTextTheme(Brightness brightness) {
  const baseTheme = TextTheme(
    bodyLarge: TextStyle(),
    bodyMedium: TextStyle(),
    bodySmall: TextStyle(),
    labelLarge: TextStyle(),
    labelMedium: TextStyle(),
    labelSmall: TextStyle(),
    titleLarge: TextStyle(),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    titleSmall: TextStyle(),
  );
  if (kIsWeb) {
    return _applyFontFallback(baseTheme, _webChineseFontFallback);
  }
  return baseTheme
      .apply(fontFamily: 'LatoLato')
      .useSystemChineseFont(brightness);
}

TextTheme _applyFontFallback(TextTheme textTheme, List<String> fallback) {
  return textTheme.copyWith(
    bodyLarge: _applyTextStyleFallback(textTheme.bodyLarge, fallback),
    bodyMedium: _applyTextStyleFallback(textTheme.bodyMedium, fallback),
    bodySmall: _applyTextStyleFallback(textTheme.bodySmall, fallback),
    labelLarge: _applyTextStyleFallback(textTheme.labelLarge, fallback),
    labelMedium: _applyTextStyleFallback(textTheme.labelMedium, fallback),
    labelSmall: _applyTextStyleFallback(textTheme.labelSmall, fallback),
    titleLarge: _applyTextStyleFallback(textTheme.titleLarge, fallback),
    titleMedium: _applyTextStyleFallback(textTheme.titleMedium, fallback),
    titleSmall: _applyTextStyleFallback(textTheme.titleSmall, fallback),
  );
}

TextStyle? _applyTextStyleFallback(TextStyle? style, List<String> fallback) {
  return style?.copyWith(fontFamilyFallback: fallback);
}
