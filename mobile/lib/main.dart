import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

const _claveModoOscuro = 'modo_oscuro';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencias = await SharedPreferences.getInstance();
  runApp(
    BitacoraAvesApp(
      preferencias: preferencias,
      modoOscuroInicial: preferencias.getBool(_claveModoOscuro) ?? false,
    ),
  );
}

class BitacoraAvesApp extends StatefulWidget {
  const BitacoraAvesApp({
    super.key,
    required this.preferencias,
    required this.modoOscuroInicial,
  });

  final SharedPreferences preferencias;
  final bool modoOscuroInicial;

  @override
  State<BitacoraAvesApp> createState() => _BitacoraAvesAppState();
}

class _BitacoraAvesAppState extends State<BitacoraAvesApp> {
  late bool _modoOscuro;
  final _mensajeroKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _modoOscuro = widget.modoOscuroInicial;
  }

  Future<void> _alternarTema() async {
    final nuevoModoOscuro = !_modoOscuro;
    setState(() {
      _modoOscuro = nuevoModoOscuro;
    });

    final guardado = await widget.preferencias.setBool(
      _claveModoOscuro,
      nuevoModoOscuro,
    );
    if (!guardado) {
      _mensajeroKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia de tema.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _mensajeroKey,
      debugShowCheckedModeBanner: false,
      title: 'Bitácora de Aves',
      themeMode: _modoOscuro ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.claro(),
      darkTheme: AppTheme.oscuro(),
      home: HomeScreen(onAlternarTema: _alternarTema),
    );
  }
}
