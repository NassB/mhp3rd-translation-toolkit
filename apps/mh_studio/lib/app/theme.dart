import 'package:flutter/material.dart';

/// Thème Material 3 de l'application.
ThemeData studioTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF8A5A2B),
  brightness: brightness,
);
