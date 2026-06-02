part of '../main.dart';

ThemeData _buildOwmTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccentYellow,
    brightness: Brightness.light,
    primary: kDeepGold,
    secondary: kAccentYellow,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F6F4),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrandBlack,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      prefixIconColor: kDeepGold,
      suffixIconColor: kDeepGold,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDeepGold, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E1D4)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccentYellow,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrandBlack,
        side: const BorderSide(color: kDeepGold),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: kAccentYellow,
      thumbColor: kDeepGold,
      inactiveTrackColor: Colors.grey.shade300,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kAccentYellow
            : Colors.grey.shade500,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? kDeepGold.withValues(alpha: 0.42)
            : Colors.grey.shade300,
      ),
    ),
  );
}

class OwmBrandMark extends StatelessWidget {
  const OwmBrandMark({super.key, this.size = 58, this.badge = false});

  final double size;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(badge ? size / 2 : 14),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: kAccentYellow.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        badge ? kBrandBadgeAsset : kBrandLogoAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            kBrandShort,
            style: TextStyle(
              color: kAccentYellow,
              fontSize: size * 0.28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class BrandedSplashScreen extends StatelessWidget {
  const BrandedSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandBlack,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MotionLinesPainter())),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const OwmBrandMark(size: 116),
                  const SizedBox(height: 24),
                  const Text(
                    kBrandName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ride  Moto  Courier',
                    style: TextStyle(
                      color: kAccentYellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fast delivery. Real-time tracking.',
                    style: TextStyle(
                      color: kMutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 5,
                      color: kAccentYellow,
                      backgroundColor: kBrandSurfaceAlt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kAccentYellow.withValues(alpha: 0.16)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.16 + i * 0.08);
      canvas.drawLine(
        Offset(size.width * -0.1, y),
        Offset(size.width * (0.24 + i * 0.08), y - 42),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// OmwWelcomeScreen — first-launch branding page shown before the main shell
// ---------------------------------------------------------------------------

class OmwWelcomeScreen extends StatelessWidget {
  const OmwWelcomeScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandBlack,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MotionLinesPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  const Center(child: OwmBrandMark(size: 110)),
                  const SizedBox(height: 32),
                  const Text(
                    'On My Way',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Marketplace · Ride · Delivery · Butler',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kAccentYellow,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Shop local stores, book a ride, or send a package —\nall in one app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kMutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                  const Spacer(flex: 3),
                  FilledButton(
                    onPressed: onGetStarted,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccentYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: const Text('Get Started'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By continuing you accept our Terms of Service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kMutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
