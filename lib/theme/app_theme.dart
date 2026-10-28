import 'package:flutter/material.dart';

abstract final class PetalPopColors {
  static const blush = Color(0xFFFFF1F6);
  static const softPink = Color(0xFFFFDCE9);
  static const hotPink = Color(0xFFF53D89);
  static const deepPink = Color(0xFFC92D69);
  static const petalPink = Color(0xFFFF8EB5);
  static const paleYellow = Color(0xFFFFE58B);
  static const leafGreen = Color(0xFF70B879);
  static const lavender = Color(0xFFC9B4F2);
  static const ink = Color(0xFF543044);
  static const mutedInk = Color(0xFF9B7287);
}

abstract final class PetalPopTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PetalPopColors.hotPink,
          brightness: Brightness.light,
        ).copyWith(
          primary: PetalPopColors.hotPink,
          onPrimary: Colors.white,
          secondary: PetalPopColors.lavender,
          surface: Colors.white,
          onSurface: PetalPopColors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PetalPopColors.blush,
      cardColor: Colors.white,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: PetalPopColors.deepPink,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
        ),
        titleLarge: TextStyle(
          color: PetalPopColors.ink,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(color: PetalPopColors.mutedInk, height: 1.45),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PetalPopColors.hotPink,
          foregroundColor: Colors.white,
          minimumSize: const Size(160, 54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PetalPopColors.deepPink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: PetalPopColors.hotPink,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFFF78AA),
          onPrimary: const Color(0xFF4A132D),
          secondary: const Color(0xFFD3B9FF),
          surface: const Color(0xFF30232D),
          onSurface: const Color(0xFFFFEAF2),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF211820),
      cardColor: colorScheme.surface,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Color(0xFFFFA6C6),
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
        ),
        titleLarge: TextStyle(
          color: Color(0xFFFFEAF2),
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(color: Color(0xFFD9B9CA), height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF5D98),
          foregroundColor: Colors.white,
          minimumSize: const Size(160, 54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFC92D69),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
