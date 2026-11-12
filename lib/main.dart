import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/splash_screen.dart';
import 'storage.dart';
import 'theme.dart';

void main() {
  runApp(const KainuwaStudioApp());
}

class KainuwaStudioApp extends StatefulWidget {
  const KainuwaStudioApp({super.key});

  @override
  State<KainuwaStudioApp> createState() => _KainuwaStudioAppState();
}

class _KainuwaStudioAppState extends State<KainuwaStudioApp> {
  late final AppState _state = AppState(StorageService());

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'Kainuwa Studio',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
