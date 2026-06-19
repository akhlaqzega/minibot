import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // Warna Utama (Default Neon Blue)
  Color _primaryColor = const Color(0xFF00D4FF);
  Color get primaryColor => _primaryColor;

  // Warna Aksen/Glow (Default Neon Red)
  Color _accentColor = const Color(0xFFFF2D55);
  Color get accentColor => _accentColor;

  bool get isDark => _themeMode == ThemeMode.dark;

  // Mengubah mode gelap / terang
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Mengubah kombinasi warna utama
  void setColorTheme(Color primary, Color accent) {
    _primaryColor = primary;
    _accentColor = accent;
    notifyListeners();
  }

  // Preset kombinasi warna
  static final List<ColorPreset> colorPresets = [
    ColorPreset(
      name: "Cyberpunk Classic",
      primary: const Color(0xFF00D4FF), // Neon Blue
      accent: const Color(0xFFFF2D55),  // Neon Red
    ),
    ColorPreset(
      name: "Matrix Green",
      primary: const Color(0xFF00FF9C), // Neon Green
      accent: const Color(0xFF00D4FF),  // Neon Blue
    ),
    ColorPreset(
      name: "Volt Gold",
      primary: const Color(0xFFFFD60A), // Neon Yellow
      accent: const Color(0xFFFF6B35),  // Neon Orange
    ),
    ColorPreset(
      name: "Sunset Purple",
      primary: const Color(0xFFD000FF), // Neon Purple
      accent: const Color(0xFFFF007F),  // Neon Magenta
    ),
  ];
}

class ColorPreset {
  final String name;
  final Color primary;
  final Color accent;

  ColorPreset({
    required this.name,
    required this.primary,
    required this.accent,
  });
}
