import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final state = AppScope.read(context);
    await Future.wait<void>([
      state.load(),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KColors.deepPurple, KColors.purple],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              double part(double a, double b, [Curve curve = Curves.easeOut]) =>
                  curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0).toDouble());
              final logoIn = part(0.0, 0.5, Curves.easeOutBack);
              final logoFade = part(0.0, 0.3);
              final glow = part(0.0, 0.7);
              final text = part(0.45, 0.8);
              final bar = part(0.1, 1.0, Curves.easeInOut);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.55 * glow,
                          child: Container(
                            width: 120 + 180 * glow,
                            height: 120 + 180 * glow,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [Color(0x66FFC21A), Color(0x00FFC21A)]),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: logoFade,
                          child: Transform.scale(
                            scale: 0.55 + 0.45 * logoIn,
                            child: Image.asset('assets/icon/app_icon.png', width: 240),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - text)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Create Professional\nVideos on Your Phone',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 17, height: 1.4, letterSpacing: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 150,
                      height: 4,
                      child: Stack(
                        children: [
                          const ColoredBox(color: Color(0x33FFFFFF), child: SizedBox.expand()),
                          FractionallySizedBox(
                            widthFactor: bar,
                            child: const ColoredBox(color: KColors.gold, child: SizedBox.expand()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
    );
  }
}
