import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/reading_settings_service.dart';
import '../theme/app_theme.dart';

class ReadingSettingsScreen extends StatefulWidget {
  const ReadingSettingsScreen({super.key});

  @override
  State<ReadingSettingsScreen> createState() =>
      _ReadingSettingsScreenState();
}

class _ReadingSettingsScreenState
    extends State<ReadingSettingsScreen> {
  final ReadingSettingsService _service =
      ReadingSettingsService();

  String _fontFamily = 'Noto Sans';
  double _fontSize = 18;
  double _lineHeight = 1.9;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _service.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _fontFamily = settings.fontFamily;
      _fontSize = settings.fontSize;
      _lineHeight = settings.lineHeight;
      _loading = false;
    });
  }

  Future<void> _save({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
  }) async {
    final nextFont = fontFamily ?? _fontFamily;
    final nextSize = fontSize ?? _fontSize;
    final nextHeight = lineHeight ?? _lineHeight;

    setState(() {
      _fontFamily = nextFont;
      _fontSize = nextSize;
      _lineHeight = nextHeight;
    });

    await _service.save(
      ReadingSettings(
        fontFamily: nextFont,
        fontSize: nextSize,
        lineHeight: nextHeight,
      ),
    );
  }

  TextStyle _readerStyle({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
  }) {
    final family = fontFamily ?? _fontFamily;

    final style = TextStyle(
      color: AppColors.readerText,
      fontSize: fontSize ?? _fontSize,
      height: lineHeight ?? _lineHeight,
      fontWeight: FontWeight.w400,
    );

    switch (family) {
      case 'Noto Serif':
        return GoogleFonts.notoSerif(textStyle: style);

      case 'Roboto':
        return GoogleFonts.roboto(textStyle: style);

      case 'PT Serif':
        return GoogleFonts.ptSerif(textStyle: style);

      case 'Noto Sans':
      default:
        return GoogleFonts.notoSans(textStyle: style);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Унших тохиргоо'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Фонт',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      ReadingSettingsService.availableFonts
                          .map(
                    (font) {
                      return ChoiceChip(
                        label: Text(
                          font,
                          style: _readerStyle(
                            fontFamily: font,
                            fontSize: 14,
                            lineHeight: 1.2,
                          ),
                        ),
                        selected: _fontFamily == font,
                        onSelected: (_) {
                          _save(fontFamily: font);
                        },
                      );
                    },
                  ).toList(),
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Үсгийн хэмжээ',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_fontSize.round()} px',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                Slider(
                  value: _fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    _save(fontSize: value);
                  },
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Мөр хоорондын зай',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _lineHeight.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                Slider(
                  value: _lineHeight,
                  min: 1.2,
                  max: 2.4,
                  divisions: 12,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    _save(lineHeight: value);
                  },
                ),

                const SizedBox(height: 32),

                Text(
                  'Жишээ',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.readerBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Ном унших мөчид үг бүр өөрийн гэсэн '
                    'ертөнцийг бүтээдэг. Эндээс фонт, үсгийн '
                    'хэмжээ болон мөр хоорондын зай хэрхэн '
                    'харагдахыг урьдчилан харж болно.',
                    style: _readerStyle(),
                  ),
                ),
              ],
            ),
    );
  }
}
