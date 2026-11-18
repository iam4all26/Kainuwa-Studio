import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'control/app_control.dart';
import 'screens/splash_screen.dart';
import 'storage.dart';
import 'store/store_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status bar and the camera cutout (the editor handles safe areas itself).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await StoreService.instance.init();
  runApp(const KainuwaStudioApp());
}

class KainuwaStudioApp extends StatefulWidget {
  const KainuwaStudioApp({super.key});

  @override
  State<KainuwaStudioApp> createState() => _KainuwaStudioAppState();
}

class _KainuwaStudioAppState extends State<KainuwaStudioApp> with WidgetsBindingObserver {
  late final AppState _state = AppState(StorageService());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Look at the owner's control file a few seconds after start, once the first screen is up.
    Future<void>.delayed(const Duration(seconds: 5), () => AppControl.instance.run());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppControl.instance.onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'Kainuwa Studio',
        navigatorKey: appNavKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) {
          // Phones set to very large text would otherwise break the layout.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
