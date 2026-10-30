import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'fotos_service.dart';

/// Resultado de subir un avistamiento al BFF.
enum ResultadoSubidaAvistamiento { subida, encolada, sinSesion }

/// Resultado de reintentar la cola de subidas pendientes.
enum ResultadoReintentosSubida { sinPendientes, todasSubidas, quedanPendientes }

/// Cola de subidas al BFF que quedaron pendientes por falta de conexión.
class SubidasPendientesService {
  SubidasPendientesService({FotosService? fotosServicio})
    : _fotosServicio = fotosServicio ?? FotosService();

  static const claveSubidasPendientes = 'subidas_bff_pendientes_v1';

  final FotosService _fotosServicio;

  /// Intenta subir la foto pendiente. Devuelve `false` si no se pudo subir.
  Future<bool> intentarSubida(Map<String, String> pendiente) async {
    final ruta = pendiente['rutaImagen'];
    if (ruta == null || !await File(ruta).exists()) return false;
    try {
      final bytes = await File(ruta).readAsBytes();
      final nombreArchivo = ruta.split(Platform.pathSeparator).last;
      final contentType = nombreArchivo.toLowerCase().endsWith('.png')
          ? 'image/png'
          : nombreArchivo.toLowerCase().endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      await _fotosServicio.subirFoto(
        bytes: bytes,
        nombreArchivo: nombreArchivo,
        contentType: contentType,
        categoria: pendiente['categoria'] ?? 'otras',
        lugar: pendiente['lugar'],
        fecha: pendiente['fecha'],
        comentario: pendiente['comentario'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sube [pendiente] al BFF o la encola para reintentar más tarde.
  Future<ResultadoSubidaAvistamiento> subirOEncolar(
    Map<String, String> pendiente,
  ) async {
    final token = await AuthService().obtenerToken();
    if (token == null) return ResultadoSubidaAvistamiento.sinSesion;

    final exito = await intentarSubida(pendiente);
    if (exito) return ResultadoSubidaAvistamiento.subida;

    final preferencias = await SharedPreferences.getInstance();
    final actual = preferencias.getString(claveSubidasPendientes);
    final lista = <Map<String, String>>[];
    if (actual != null) {
      try {
        final json = jsonDecode(actual);
        if (json is List<dynamic>) {
          for (final item in json) {
            if (item is Map<String, dynamic>) {
              lista.add(item.map((k, v) => MapEntry(k, v.toString())));
            }
          }
        }
      } on FormatException {
        // cola corrupta: se descarta
      }
    }
    lista.add(pendiente);
    await preferencias.setString(claveSubidasPendientes, jsonEncode(lista));
    return ResultadoSubidaAvistamiento.encolada;
  }

  /// Reintenta todas las subidas encoladas y actualiza la cola guardada.
  Future<ResultadoReintentosSubida> reintentarPendientes() async {
    final token = await AuthService().obtenerToken();
    if (token == null) return ResultadoReintentosSubida.sinPendientes;

    final preferencias = await SharedPreferences.getInstance();
    final actual = preferencias.getString(claveSubidasPendientes);
    if (actual == null) return ResultadoReintentosSubida.sinPendientes;

    final lista = <Map<String, String>>[];
    try {
      final json = jsonDecode(actual);
      if (json is List<dynamic>) {
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            lista.add(item.map((k, v) => MapEntry(k, v.toString())));
          }
        }
      }
    } on FormatException {
      await preferencias.remove(claveSubidasPendientes);
      return ResultadoReintentosSubida.sinPendientes;
    }
    if (lista.isEmpty) return ResultadoReintentosSubida.sinPendientes;

    final restantes = <Map<String, String>>[];
    for (final pendiente in lista) {
      final exito = await intentarSubida(pendiente);
      if (!exito) restantes.add(pendiente);
    }

    if (restantes.isEmpty) {
      await preferencias.remove(claveSubidasPendientes);
      return ResultadoReintentosSubida.todasSubidas;
    }

    await preferencias.setString(claveSubidasPendientes, jsonEncode(restantes));
    return ResultadoReintentosSubida.quedanPendientes;
  }
}
