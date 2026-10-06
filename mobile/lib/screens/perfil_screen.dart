import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, required this.reportesGuardados});

  final int reportesGuardados;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _authService = AuthService();
  Usuario? _usuario;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  Future<void> _cargarSesion() async {
    final usuario = await _authService.obtenerSesion();
    if (!mounted) return;
    setState(() {
      _usuario = usuario;
      _cargando = false;
    });
  }

  Future<void> _abrirLogin() async {
    final inicio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (inicio == true) await _cargarSesion();
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres cerrar tu sesión en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _authService.cerrarSesion();
    if (!mounted) return;
    setState(() => _usuario = null);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Sesión cerrada.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _usuario == null
                  ? Icons.person_outline_rounded
                  : Icons.account_circle_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              _usuario == null ? 'Sin sesión' : _usuario!.nombre,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_usuario != null) ...[
              const SizedBox(height: 6),
              Text(_usuario!.email),
            ],
            const SizedBox(height: 16),
            Text(
              'Reportes guardados en este dispositivo: ${widget.reportesGuardados}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Los reportes aún no se envían al equipo de moderación.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_usuario == null)
              FilledButton.icon(
                onPressed: _abrirLogin,
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión'),
              )
            else
              OutlinedButton.icon(
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
          ],
        ),
      ),
    );
  }
}
