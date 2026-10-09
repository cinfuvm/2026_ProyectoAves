import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aparicion_diferida.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formularioKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formularioKey.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _authService.iniciarSesion(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar sesión'),
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
                        Icons.flutter_dash_rounded,
                        color: PaletaAves.morado,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (valor) =>
                          valor == null || valor.trim().isEmpty
                          ? 'Ingresa tu correo'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (valor) =>
                          valor == null || valor.trim().isEmpty
                          ? 'Ingresa tu contraseña'
                          : null,
                    ),
                    AnimatedSwitcher(
                      duration: duracion(context, 180),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (hijo, anim) => FadeTransition(
                        opacity: anim,
                        child: hijo,
                      ),
                      child: _error == null
                          ? const SizedBox.shrink(
                              key: ValueKey<String>('sin-error'),
                            )
                          : Padding(
                              key: const ValueKey<String>('error-login'),
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
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
                        onPressed: _cargando ? null : _entrar,
                        icon: AnimatedSwitcher(
                          duration: duracion(context, 160),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (hijo, anim) => ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.7,
                              end: 1,
                            ).animate(anim),
                            child: FadeTransition(opacity: anim, child: hijo),
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  key: ValueKey<String>('cargando'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.login,
                                  key: ValueKey<String>('listo'),
                                ),
                        ),
                        label: const Text('Entrar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sesión de demostración. El BFF con autenticación real '
                      'está en planificación.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: marca.textoSecundario,
                      ),
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
