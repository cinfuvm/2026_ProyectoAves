import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aparicion_diferida.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formularioKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmacionController = TextEditingController();
  final _authService = AuthService();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (!(_formularioKey.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _authService.registrarse(
        user: _usuarioController.text,
        password: _passwordController.text,
        confirmacion: _confirmacionController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'No se pudo conectar con el servidor.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // El backend admite de 3 a 30 caracteres (ver `Aves.Accounts.User`).
  String? _validarUsuario(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresa tu usuario';
    if (texto.length < 3 || texto.length > 30) {
      return 'Debe tener entre 3 y 30 caracteres';
    }
    return null;
  }

  String? _validarPassword(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Ingresa una contraseña';
    if (texto.length < 8) return 'Usa al menos 8 caracteres';
    return null;
  }

  String? _validarConfirmacion(String? valor) {
    if (valor == null || valor.isEmpty) return 'Repite la contraseña';
    if (valor != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        flexibleSpace: SizedBox(
          width: double.infinity,
          height: MediaQuery.paddingOf(context).top + kToolbarHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [PaletaAves.morado, PaletaAves.violeta],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AparicionDiferida(
              indice: 0,
              activa: true,
              duracionMs: 450,
              child: Form(
                key: _formularioKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: PaletaAves.amarillo,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: PaletaAves.morado,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usuarioController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      validator: _validarUsuario,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        helperText: 'Mínimo 8 caracteres',
                      ),
                      validator: _validarPassword,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmacionController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _crearCuenta(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                      validator: _validarConfirmacion,
                    ),
                    AnimatedSwitcher(
                      duration: duracion(context, 180),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (hijo, anim) =>
                          FadeTransition(opacity: anim, child: hijo),
                      child: _error == null
                          ? const SizedBox.shrink(
                              key: ValueKey<String>('sin-error'),
                            )
                          : Padding(
                              key: const ValueKey<String>('error-registro'),
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _cargando ? null : _crearCuenta,
                        icon: _cargando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Crear cuenta'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tu usuario será tu identificador público en la bitácora.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: marca.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
