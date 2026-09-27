import 'package:shared_preferences/shared_preferences.dart';

class ReadingSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;

  const ReadingSettings({
    this.fontFamily = 'Noto Sans',
    this.fontSize = 18,
    this.lineHeight = 1.9,
  });

  ReadingSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
  }) {
    return ReadingSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}

class ReadingSettingsService {
  static const _fontFamilyKey = 'reading_font_family';
  static const _fontSizeKey = 'reading_font_size';
  static const _lineHeightKey = 'reading_line_height';

  static const List<String> availableFonts = [
    'Noto Sans',
    'Noto Serif',
    'Roboto',
    'PT Serif',
  ];

  Future<ReadingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedFont = prefs.getString(_fontFamilyKey);
    final fontFamily = availableFonts.contains(savedFont)
        ? savedFont!
        : 'Noto Sans';

    final fontSize = _clamp(
      prefs.getDouble(_fontSizeKey) ?? 18,
      14,
      28,
    );

    final lineHeight = _clamp(
      prefs.getDouble(_lineHeightKey) ?? 1.9,
      1.2,
      2.4,
    );

    return ReadingSettings(
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
  }

  Future<void> saveFontFamily(String value) async {
    if (!availableFonts.contains(value)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, value);
  }

  Future<void> saveFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      _fontSizeKey,
      _clamp(value, 14, 28),
    );
  }

  Future<void> saveLineHeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      _lineHeightKey,
      _clamp(value, 1.2, 2.4),
    );
  }

  Future<void> save(ReadingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    final fontFamily =
        availableFonts.contains(settings.fontFamily)
            ? settings.fontFamily
            : 'Noto Sans';

    await Future.wait([
      prefs.setString(_fontFamilyKey, fontFamily),
      prefs.setDouble(
        _fontSizeKey,
        _clamp(settings.fontSize, 14, 28),
      ),
      prefs.setDouble(
        _lineHeightKey,
        _clamp(settings.lineHeight, 1.2, 2.4),
      ),
    ]);
  }

  double _clamp(
    double value,
    double min,
    double max,
  ) {
    return value.clamp(min, max).toDouble();
  }
}
