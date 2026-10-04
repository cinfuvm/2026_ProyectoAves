import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const BitacoraAvesApp());
}

class BitacoraAvesApp extends StatefulWidget {
  const BitacoraAvesApp({super.key});

  @override
  State<BitacoraAvesApp> createState() => _BitacoraAvesAppState();
}

class _BitacoraAvesAppState extends State<BitacoraAvesApp> {
  bool _modoOscuro = false;

  @override
  Widget build(BuildContext context) {
    const morado = Color(0xFF5B2D91);
    const amarillo = Color(0xFFFFD447);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bitácora de Aves',
      themeMode: _modoOscuro ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: morado,
          primary: morado,
          secondary: amarillo,
          surface: const Color(0xFFFFFCFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF8FF),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 5,
          shadowColor: morado.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5D8F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE5D8F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: morado, width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC69BFF),
          brightness: Brightness.dark,
          primary: const Color(0xFFD1B2FF),
          secondary: amarillo,
          surface: const Color(0xFF1D1726),
        ),
        scaffoldBackgroundColor: const Color(0xFF15111C),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF241D2E),
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF241D2E),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF51415F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF51415F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD1B2FF), width: 1.5),
          ),
        ),
      ),
      home: HomeScreen(
        modoOscuro: _modoOscuro,
        onAlternarTema: () {
          setState(() {
            _modoOscuro = !_modoOscuro;
          });
        },
      ),
    );
  }
}
