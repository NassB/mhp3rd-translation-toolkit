import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// Application racine : Material 3, thème sombre par défaut (skill studio-ui).
class StudioApp extends StatefulWidget {
  const StudioApp({super.key});

  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  // Un routeur par instance : pas d'état de navigation partagé entre tests.
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MHP3rd Studio',
      theme: studioTheme(Brightness.light),
      darkTheme: studioTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
