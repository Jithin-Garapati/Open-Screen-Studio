import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0F1117),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF7C4DFF),
    secondary: Color(0xFF64FFDA),
    surface: Color(0xFF1A1C25),
    onSurface: Colors.white,
  ),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
); 