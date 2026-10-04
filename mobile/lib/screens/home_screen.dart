import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class _ColoresAves {
  static const morado = Color(0xFF5B2D91);
  static const violeta = Color(0xFF8B5CC7);
  static const lavanda = Color(0xFFF2EAFB);
  static const amarillo = Color(0xFFFFD447);
  static const fondo = Color(0xFFFBF8FF);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.modoOscuro,
    required this.onAlternarTema,
  });

  final bool modoOscuro;
  final VoidCallback onAlternarTema;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _claveColeccion = 'fotos_guardadas_wikipedia_v1';
  static const _claveAvistamientos = 'avistamientos_propios_v1';
  static const _claveReportes = 'reportes_fotos_pendientes_v1';
  static const _motivosReporte = [
    'La foto no muestra un ave',
    'Contenido inapropiado',
    'La imagen o información es engañosa',
    'Imagen duplicada o de baja calidad',
    'Otro motivo',
  ];

  int _indiceSeleccionado = 0;
  final ImagePicker _selectorImagen = ImagePicker();
  final TextEditingController _controladorBusqueda = TextEditingController();
  List<_FotoGuardada> _fotosGuardadas = [];
  List<_AvistamientoPropio> _avistamientosPropios = [];
  List<_ReporteFoto> _reportesFotos = [];
  final Set<String> _avesGuardandose = {};
  bool _cargandoColeccion = true;
  bool _guardandoAvistamiento = false;
  String? _errorColeccion;
  String _consulta = '';
  String _categoriaSeleccionada = 'Todas';
  String _filtroTipoColeccion = 'Todo';
  String _filtroCategoriaColeccion = 'Todas';
  late Future<List<_AveWikipedia>> _aves;

  static const List<String> _categorias = [
    'Todas',
    'Bosque',
    'Rapaces',
    'Humedal',
    'Pradera',
    'Picaflores',
  ];
  static const List<String> _categoriasColeccion = [
    ..._categorias,
    'Sin clasificar',
  ];
  static const List<String> _tiposColeccion = [
    'Todo',
    'Aves guardadas',
    'Mis avistamientos',
  ];

  static const List<({String nombre, String pagina, String categoria})>
  _catalogo = [
    (nombre: 'Chucao', pagina: 'Chucao', categoria: 'Bosque'),
    (nombre: 'Cóndor andino', pagina: 'Cóndor_andino', categoria: 'Rapaces'),
    (nombre: 'Loica común', pagina: 'Sturnella_loyca', categoria: 'Pradera'),
    (
      nombre: 'Flamenco chileno',
      pagina: 'Flamenco_austral',
      categoria: 'Humedal',
    ),
    (
      nombre: 'Carpintero negro',
      pagina: 'Campephilus_magellanicus',
      categoria: 'Bosque',
    ),
    (
      nombre: 'Picaflor gigante',
      pagina: 'Patagona_gigas',
      categoria: 'Picaflores',
    ),
    (nombre: 'Chincol', pagina: 'Zonotrichia_capensis', categoria: 'Pradera'),
  ];

  @override
  void initState() {
    super.initState();
    _aves = _cargarAves();
    _cargarColeccion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recuperarImagenPerdida();
    });
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<List<_AveWikipedia>> _cargarAves() async {
    final respuestas = await Future.wait(
      _catalogo.map((ave) async {
        final uri = Uri.https(
          'es.wikipedia.org',
          '/api/rest_v1/page/summary/${ave.pagina}',
        );
        final respuesta = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        if (respuesta.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Wikipedia respondió con estado ${respuesta.statusCode}.',
            uri: uri,
          );
        }

        final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
        if (datos is! Map<String, dynamic>) {
          throw const FormatException('Respuesta inesperada de Wikipedia.');
        }

        final miniatura = datos['thumbnail'];
        final contenido = datos['content_urls'];
        final imagen = miniatura is Map<String, dynamic>
            ? miniatura['source'] as String?
            : null;
        final pagina = contenido is Map<String, dynamic>
            ? contenido['desktop']
            : null;
        final enlace = pagina is Map<String, dynamic>
            ? pagina['page'] as String?
            : null;

        if (imagen == null || enlace == null) {
          throw FormatException(
            'El artículo ${ave.nombre} no tiene imagen o enlace disponible.',
          );
        }

        return _AveWikipedia(
          nombre: ave.nombre,
          categoria: ave.categoria,
          nombreCientifico: datos['title'] as String? ?? ave.pagina,
          descripcion: datos['extract'] as String? ?? '',
          urlImagen: imagen,
          urlArticulo: enlace,
        );
      }),
    );

    return respuestas;
  }

  Future<void> _cargarColeccion() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardadasJson = preferencias.getString(_claveColeccion);
      final avistamientosJson = preferencias.getString(_claveAvistamientos);
      final reportesJson = preferencias.getString(_claveReportes);
      final fotos = <_FotoGuardada>[];
      final avistamientos = <_AvistamientoPropio>[];
      final reportes = <_ReporteFoto>[];

      if (guardadasJson != null) {
        final datos = jsonDecode(guardadasJson);
        if (datos is! List<dynamic>) {
          throw const FormatException('Formato de colección no válido.');
        }

        for (final dato in datos) {
          if (dato is! Map<String, dynamic>) {
            throw const FormatException('Elemento de colección no válido.');
          }
          fotos.add(_FotoGuardada.fromJson(dato));
        }
      }

      if (avistamientosJson != null) {
        final datos = jsonDecode(avistamientosJson);
        if (datos is! List<dynamic>) {
          throw const FormatException('Formato de avistamientos no válido.');
        }

        for (final dato in datos) {
          if (dato is! Map<String, dynamic>) {
            throw const FormatException('Elemento de avistamiento no válido.');
          }
          avistamientos.add(_AvistamientoPropio.fromJson(dato));
        }
      }

      if (reportesJson != null) {
        final datos = jsonDecode(reportesJson);
        if (datos is! List<dynamic>) {
          throw const FormatException('Formato de reportes no válido.');
        }

        for (final dato in datos) {
          if (dato is! Map<String, dynamic>) {
            throw const FormatException('Elemento de reporte no válido.');
          }
          reportes.add(_ReporteFoto.fromJson(dato));
        }
      }

      if (!mounted) return;
      setState(() {
        _fotosGuardadas = fotos;
        _avistamientosPropios = avistamientos;
        _reportesFotos = reportes;
        _cargandoColeccion = false;
        _errorColeccion = null;
      });
    } on FormatException catch (error) {
      _informarErrorColeccion(error.message);
    } on PlatformException catch (error) {
      _informarErrorColeccion(
        error.message ?? 'No se pudo leer la colección guardada.',
      );
    } on MissingPluginException catch (error) {
      _informarErrorColeccion(error.message ?? 'Almacenamiento no disponible.');
    }
  }

  void _informarErrorColeccion(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargandoColeccion = false;
      _errorColeccion = mensaje;
    });
  }

  Future<void> _guardarAve(_AveWikipedia ave) async {
    if (_fotosGuardadas.any((foto) => foto.urlArticulo == ave.urlArticulo) ||
        _avesGuardandose.contains(ave.urlArticulo)) {
      return;
    }

    setState(() {
      _avesGuardandose.add(ave.urlArticulo);
    });

    try {
      final uriImagen = Uri.parse(ave.urlImagen);
      final respuesta = await http
          .get(uriImagen)
          .timeout(const Duration(seconds: 30));
      if (respuesta.statusCode != HttpStatus.ok) {
        throw HttpException(
          'La descarga de la imagen falló (${respuesta.statusCode}).',
          uri: uriImagen,
        );
      }
      if (respuesta.bodyBytes.isEmpty ||
          !(respuesta.headers['content-type']?.startsWith('image/') ?? false)) {
        throw const FormatException(
          'Wikipedia no devolvió un archivo de imagen válido.',
        );
      }

      final directorioApp = await getApplicationDocumentsDirectory();
      final directorioColeccion = Directory(
        '${directorioApp.path}${Platform.pathSeparator}coleccion_aves',
      );
      await directorioColeccion.create(recursive: true);

      final nombreArchivoFuente = uriImagen.pathSegments.last;
      final extension =
          RegExp(
            r'\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ).firstMatch(nombreArchivoFuente)?.group(0)?.toLowerCase() ??
          '.jpg';
      final nombreSeguro = Uri.parse(ave.urlArticulo).pathSegments.last
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final nombreArchivo =
          '${nombreSeguro}_${DateTime.now().microsecondsSinceEpoch}$extension';
      final rutaImagen =
          '${directorioColeccion.path}${Platform.pathSeparator}$nombreArchivo';
      final archivoTemporal = File('$rutaImagen.tmp');
      await archivoTemporal.writeAsBytes(respuesta.bodyBytes, flush: true);
      await archivoTemporal.rename(rutaImagen);

      final fotoGuardada = _FotoGuardada(
        nombre: ave.nombre,
        categoria: ave.categoria,
        nombreCientifico: ave.nombreCientifico,
        descripcion: ave.descripcion,
        rutaImagen: rutaImagen,
        urlImagen: ave.urlImagen,
        urlArticulo: ave.urlArticulo,
      );
      final nuevasFotos = [..._fotosGuardadas, fotoGuardada];
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveColeccion,
        jsonEncode(nuevasFotos.map((foto) => foto.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('No se pudieron guardar los datos de la colección.');
      }

      if (!mounted) return;
      setState(() {
        _fotosGuardadas = nuevasFotos;
      });
      _mostrarMensaje('${ave.nombre} se guardó en tu colección.');
    } on TimeoutException catch (error) {
      _mostrarErrorGuardar('La descarga tardó demasiado: $error');
    } on http.ClientException catch (error) {
      _mostrarErrorGuardar('No se pudo descargar la imagen: $error');
    } on HttpException catch (error) {
      _mostrarErrorGuardar(error.message);
    } on FileSystemException catch (error) {
      _mostrarErrorGuardar('No se pudo guardar el archivo: ${error.message}');
    } on FormatException catch (error) {
      _mostrarErrorGuardar(error.message);
    } on PlatformException catch (error) {
      _mostrarErrorGuardar(
        error.message ?? 'No se pudo acceder al almacenamiento local.',
      );
    } on MissingPluginException catch (error) {
      _mostrarErrorGuardar(
        error.message ?? 'El almacenamiento local no está disponible.',
      );
    } on StateError catch (error) {
      _mostrarErrorGuardar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _avesGuardandose.remove(ave.urlArticulo);
        });
      }
    }
  }

  void _mostrarErrorGuardar(String mensaje) {
    _mostrarMensaje('No se pudo guardar el ave: $mensaje');
  }

  Future<void> _quitarAvistamiento(_AvistamientoPropio avistamiento) async {
    try {
      final nuevosAvistamientos = _avistamientosPropios
          .where((item) => item.rutaImagen != avistamiento.rutaImagen)
          .toList();
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveAvistamientos,
        jsonEncode(nuevosAvistamientos.map((item) => item.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('No se pudo actualizar la bitácora.');
      }

      if (!mounted) return;
      setState(() {
        _avistamientosPropios = nuevosAvistamientos;
      });

      final archivo = File(avistamiento.rutaImagen);
      if (await archivo.exists()) {
        await archivo.delete();
      }
      _mostrarMensaje('${avistamiento.nombreAve} se quitó de tu bitácora.');
    } on FileSystemException catch (error) {
      _mostrarMensaje(
        'El avistamiento se quitó de la bitácora, pero no se pudo borrar '
        'la imagen local: ${error.message}',
      );
    } on PlatformException catch (error) {
      _mostrarMensaje(
        'No se pudo actualizar la bitácora: '
        '${error.message ?? 'Error de almacenamiento local.'}',
      );
    } on MissingPluginException catch (error) {
      _mostrarMensaje(
        'No se pudo actualizar la bitácora: '
        '${error.message ?? 'El almacenamiento local no está disponible.'}',
      );
    } on StateError catch (error) {
      _mostrarMensaje('No se pudo actualizar la bitácora: ${error.message}');
    }
  }

  Future<void> _quitarDeColeccion(_FotoGuardada foto) async {
    try {
      final nuevasFotos = _fotosGuardadas
          .where((guardada) => guardada.urlArticulo != foto.urlArticulo)
          .toList();
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveColeccion,
        jsonEncode(nuevasFotos.map((guardada) => guardada.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('No se pudo actualizar la colección.');
      }

      if (!mounted) return;
      setState(() {
        _fotosGuardadas = nuevasFotos;
      });

      final archivo = File(foto.rutaImagen);
      if (await archivo.exists()) {
        await archivo.delete();
      }
      _mostrarMensaje('${foto.nombre} se quitó de tu colección.');
    } on FileSystemException catch (error) {
      _mostrarMensaje(
        'El ave se quitó de la colección, pero no se pudo borrar '
        'el archivo local: ${error.message}',
      );
    } on PlatformException catch (error) {
      _mostrarErrorColeccion(
        error.message ?? 'No se pudo actualizar la colección guardada.',
      );
    } on MissingPluginException catch (error) {
      _mostrarErrorColeccion(
        error.message ?? 'El almacenamiento local no está disponible.',
      );
    } on StateError catch (error) {
      _mostrarErrorColeccion(error.message);
    }
  }

  void _mostrarErrorColeccion(String mensaje) {
    _mostrarMensaje('No se pudo actualizar la colección: $mensaje');
  }

  void _alTocarItem(int index) {
    setState(() {
      _indiceSeleccionado = index;
    });
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarImagen(ImageSource origen) async {
    try {
      final imagen = await _selectorImagen.pickImage(source: origen);
      if (!mounted || imagen == null) return;

      await _procesarImagenSeleccionada(imagen);
    } on PlatformException catch (error) {
      _mostrarMensaje(
        'No se pudo agregar la imagen: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _recuperarImagenPerdida() async {
    try {
      final respuesta = await _selectorImagen.retrieveLostData();
      if (respuesta.isEmpty) return;
      if (respuesta.exception case final error?) {
        _mostrarErrorAvistamiento(
          error.message ?? 'Android no pudo recuperar la foto seleccionada.',
        );
        return;
      }

      final archivos = respuesta.files;
      final imagen = archivos != null && archivos.isNotEmpty
          ? archivos.first
          : respuesta.file;
      if (imagen != null && mounted) {
        await _procesarImagenSeleccionada(imagen);
      }
    } on PlatformException catch (error) {
      _mostrarErrorAvistamiento(
        error.message ?? 'No se pudo recuperar la foto seleccionada.',
      );
    } on MissingPluginException catch (error) {
      _mostrarErrorAvistamiento(
        error.message ?? 'El selector de imágenes no está disponible.',
      );
    }
  }

  Future<void> _procesarImagenSeleccionada(XFile imagen) async {
    final datosAvistamiento = await _solicitarDatosAvistamiento();
    if (!mounted || datosAvistamiento == null) return;
    await _guardarAvistamiento(imagen, datosAvistamiento);
  }

  Future<_DatosAvistamiento?> _solicitarDatosAvistamiento() async {
    return showDialog<_DatosAvistamiento>(
      context: context,
      builder: (_) =>
          _FormularioAvistamientoDialog(formatearFecha: _formatearFecha),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _guardarAvistamiento(
    XFile imagen,
    _DatosAvistamiento datos,
  ) async {
    if (!mounted || _guardandoAvistamiento) return;
    setState(() {
      _guardandoAvistamiento = true;
    });

    String? rutaImagen;
    try {
      final directorioApp = await getApplicationDocumentsDirectory();
      final directorioAvistamientos = Directory(
        '${directorioApp.path}${Platform.pathSeparator}avistamientos',
      );
      await directorioAvistamientos.create(recursive: true);

      final nombreOrigen = imagen.name;
      final extension =
          RegExp(
            r'\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ).firstMatch(nombreOrigen)?.group(0)?.toLowerCase() ??
          '.jpg';
      final nombreArchivo =
          'avistamiento_${DateTime.now().microsecondsSinceEpoch}$extension';
      rutaImagen =
          '${directorioAvistamientos.path}${Platform.pathSeparator}$nombreArchivo';
      final archivoTemporal = File('$rutaImagen.tmp');
      await File(imagen.path).copy(archivoTemporal.path);
      await archivoTemporal.rename(rutaImagen);

      final avistamiento = _AvistamientoPropio(
        nombreAve: datos.nombreAve,
        lugar: datos.lugar,
        fecha: datos.fecha,
        comentario: datos.comentario,
        rutaImagen: rutaImagen,
      );
      final nuevosAvistamientos = [avistamiento, ..._avistamientosPropios];
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveAvistamientos,
        jsonEncode(nuevosAvistamientos.map((item) => item.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('No se pudieron guardar los datos del avistamiento.');
      }

      if (!mounted) return;
      setState(() {
        _avistamientosPropios = nuevosAvistamientos;
      });
      _mostrarMensaje('La foto y los datos se guardaron en tu bitácora.');
    } on FileSystemException catch (error) {
      _mostrarErrorAvistamiento(
        'No se pudo guardar la imagen: ${error.message}',
      );
    } on http.ClientException catch (error) {
      _mostrarErrorAvistamiento(
        'No se pudo leer la imagen seleccionada: $error',
      );
    } on PlatformException catch (error) {
      _mostrarErrorAvistamiento(
        error.message ?? 'No se pudo guardar el avistamiento.',
      );
    } on MissingPluginException catch (error) {
      _mostrarErrorAvistamiento(
        error.message ?? 'El almacenamiento local no está disponible.',
      );
    } on StateError catch (error) {
      _mostrarErrorAvistamiento(error.message);
    } finally {
      if (rutaImagen != null &&
          !_avistamientosPropios.any((item) => item.rutaImagen == rutaImagen)) {
        for (final archivo in [File(rutaImagen), File('$rutaImagen.tmp')]) {
          try {
            if (await archivo.exists()) {
              await archivo.delete();
            }
          } on FileSystemException catch (error) {
            _mostrarErrorAvistamiento(
              'No se pudo limpiar la imagen temporal: ${error.message}',
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _guardandoAvistamiento = false;
        });
      }
    }
  }

  void _mostrarErrorAvistamiento(String mensaje) {
    _mostrarMensaje('No se pudo guardar la foto: $mensaje');
  }

  Future<_DatosReporte?> _solicitarMotivosReporte() async {
    final motivosSeleccionados = <String>{};
    final otroMotivoController = TextEditingController();

    try {
      return await showDialog<_DatosReporte>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, actualizarDialogo) => AlertDialog(
            title: const Text('Reportar imagen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecciona uno o más motivos:'),
                  const SizedBox(height: 8),
                  ..._motivosReporte.map(
                    (motivo) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(motivo),
                      value: motivosSeleccionados.contains(motivo),
                      onChanged: (seleccionado) {
                        actualizarDialogo(() {
                          if (seleccionado ?? false) {
                            motivosSeleccionados.add(motivo);
                          } else {
                            motivosSeleccionados.remove(motivo);
                          }
                        });
                      },
                    ),
                  ),
                  if (motivosSeleccionados.contains('Otro motivo')) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otroMotivoController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Describe el motivo',
                      ),
                      onChanged: (valor) {
                        actualizarDialogo(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed:
                    motivosSeleccionados.isEmpty ||
                        (motivosSeleccionados.contains('Otro motivo') &&
                            otroMotivoController.text.trim().isEmpty)
                    ? null
                    : () {
                        Navigator.pop(
                          dialogContext,
                          _DatosReporte(
                            motivos: motivosSeleccionados.toList(),
                            detalle: otroMotivoController.text.trim(),
                          ),
                        );
                      },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Enviar reporte'),
              ),
            ],
          ),
        ),
      );
    } finally {
      otroMotivoController.dispose();
    }
  }

  Future<void> _reportarFoto({
    required String nombre,
    required String referenciaImagen,
    required String origen,
  }) async {
    final datos = await _solicitarMotivosReporte();
    if (!mounted || datos == null) return;

    final nuevoReporte = _ReporteFoto(
      nombre: nombre,
      referenciaImagen: referenciaImagen,
      origen: origen,
      motivos: datos.motivos,
      detalle: datos.detalle,
      fechaCreacion: DateTime.now().toIso8601String(),
    );

    try {
      final nuevosReportes = [..._reportesFotos, nuevoReporte];
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveReportes,
        jsonEncode(nuevosReportes.map((reporte) => reporte.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('El dispositivo no pudo guardar el reporte.');
      }
      if (!mounted) return;

      setState(() {
        _reportesFotos = nuevosReportes;
      });
      _mostrarMensaje(
        'Reporte guardado en este dispositivo. Aún no se envía a moderación.',
      );
    } on PlatformException catch (error) {
      _mostrarErrorReporte(error.message ?? 'Error de almacenamiento local.');
    } on MissingPluginException catch (error) {
      _mostrarErrorReporte(
        error.message ?? 'El almacenamiento local no está disponible.',
      );
    } on StateError catch (error) {
      _mostrarErrorReporte(error.message);
    }
  }

  void _mostrarErrorReporte(String mensaje) {
    _mostrarMensaje('No se pudo registrar el reporte: $mensaje');
  }

  Future<void> _abrirArticulo(_AveWikipedia ave) async {
    await _abrirEnlaceFuente(ave.urlArticulo);
  }

  Future<void> _abrirEnlaceFuente(String url) async {
    final abierto = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto) {
      _mostrarMensaje('No se pudo abrir el artículo de Wikipedia.');
    }
  }

  Widget _construirInicio() {
    return _construirCatalogo(esBusqueda: false);
  }

  Widget _construirBusqueda() {
    return _construirCatalogo(esBusqueda: true);
  }

  Widget _construirCatalogo({required bool esBusqueda}) {
    return FutureBuilder<List<_AveWikipedia>>(
      future: _aves,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _ColoresAves.morado),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_outlined,
                    size: 48,
                    color: _ColoresAves.violeta,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las aves de Wikipedia. '
                    'Revisa tu conexión e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _aves = _cargarAves();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final aves = snapshot.data ?? const <_AveWikipedia>[];
        final avesVisibles = esBusqueda
            ? aves.where((ave) {
                final consulta = _consulta.toLowerCase().trim();
                final coincideCategoria =
                    _categoriaSeleccionada == 'Todas' ||
                    ave.categoria == _categoriaSeleccionada;
                final coincideTexto =
                    consulta.isEmpty ||
                    ave.nombre.toLowerCase().contains(consulta) ||
                    ave.nombreCientifico.toLowerCase().contains(consulta) ||
                    ave.descripcion.toLowerCase().contains(consulta);
                return coincideCategoria && coincideTexto;
              }).toList()
            : aves;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _construirEncabezado(esBusqueda: esBusqueda),
            if (esBusqueda) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _controladorBusqueda,
                onChanged: (valor) => setState(() => _consulta = valor),
                decoration: InputDecoration(
                  hintText: 'Nombre común o científico',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _consulta.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _controladorBusqueda.clear();
                            setState(() => _consulta = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Explorar por categoría',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categorias.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final categoria = _categorias[index];
                    return ChoiceChip(
                      label: Text(categoria),
                      selected: _categoriaSeleccionada == categoria,
                      selectedColor: _ColoresAves.morado,
                      backgroundColor: widget.modoOscuro
                          ? const Color(0xFF2B2335)
                          : Colors.white,
                      labelStyle: TextStyle(
                        color: _categoriaSeleccionada == categoria
                            ? Colors.white
                            : _ColoresAves.morado,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _categoriaSeleccionada == categoria
                            ? _ColoresAves.morado
                            : const Color(0xFFE5D8F5),
                      ),
                      onSelected: (seleccionada) {
                        if (seleccionada) {
                          setState(() {
                            _categoriaSeleccionada = categoria;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (avesVisibles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No encontramos aves con esos filtros.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...avesVisibles.map(
                (ave) => _TarjetaAve(
                  ave: ave,
                  onAbrirArticulo: () => _abrirArticulo(ave),
                  onReportar: () => _reportarFoto(
                    nombre: ave.nombre,
                    referenciaImagen: ave.urlImagen,
                    origen: 'Wikipedia',
                  ),
                  guardada: _fotosGuardadas.any(
                    (foto) => foto.urlArticulo == ave.urlArticulo,
                  ),
                  guardando: _avesGuardandose.contains(ave.urlArticulo),
                  onGuardar: () => _guardarAve(ave),
                  onQuitar: () {
                    final fotosGuardadas = _fotosGuardadas.where(
                      (foto) => foto.urlArticulo == ave.urlArticulo,
                    );
                    if (fotosGuardadas.isNotEmpty) {
                      _quitarDeColeccion(fotosGuardadas.first);
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _construirEncabezado({required bool esBusqueda}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ColoresAves.morado, _ColoresAves.violeta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ColoresAves.morado.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Icon(
              esBusqueda ? Icons.search_rounded : Icons.flutter_dash_rounded,
              size: 76,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esBusqueda ? 'Explora y descubre' : 'Aves de Chile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                esBusqueda
                    ? 'Encuentra tu próxima ave favorita.'
                    : 'Pequeños encuentros, grandes historias.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 14),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _ColoresAves.amarillo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirColeccion() {
    if (_cargandoColeccion) {
      return const Center(
        child: CircularProgressIndicator(color: _ColoresAves.morado),
      );
    }
    if (_errorColeccion != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _ColoresAves.violeta,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'No se pudo cargar tu colección: $_errorColeccion',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reintentarCargarColeccion,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final fotosVisibles = _filtroTipoColeccion == 'Mis avistamientos'
        ? const <_FotoGuardada>[]
        : _fotosGuardadas.where((foto) {
            return _filtroCategoriaColeccion == 'Todas' ||
                foto.categoria == _filtroCategoriaColeccion;
          }).toList();
    final avistamientosVisibles = _filtroTipoColeccion == 'Aves guardadas'
        ? const <_AvistamientoPropio>[]
        : _avistamientosPropios.where((avistamiento) {
            final categoria = _categoriaAvistamiento(avistamiento.nombreAve);
            return _filtroCategoriaColeccion == 'Todas' ||
                categoria == _filtroCategoriaColeccion;
          }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tu colección',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _construirFiltroColeccion(
                icono: Icons.photo_library_outlined,
                etiqueta: 'Mostrar',
                seleccionado: _filtroTipoColeccion,
                opciones: _tiposColeccion,
                onSeleccionar: (valor) {
                  setState(() {
                    _filtroTipoColeccion = valor;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _construirFiltroColeccion(
                icono: Icons.category_outlined,
                etiqueta: 'Categoría',
                seleccionado: _filtroCategoriaColeccion,
                opciones: _categoriasColeccion,
                onSeleccionar: (valor) {
                  setState(() {
                    _filtroCategoriaColeccion = valor;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_fotosGuardadas.isEmpty && _avistamientosPropios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 48,
                  color: _ColoresAves.violeta,
                ),
                SizedBox(height: 12),
                Text(
                  'Tu colección está vacía',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 6),
                Text(
                  'Guarda aves del catálogo o agrega una foto con sus datos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (avistamientosVisibles.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Avistamientos propios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ...avistamientosVisibles.map(
          (avistamiento) => _TarjetaAvistamientoPropio(
            avistamiento: avistamiento,
            fechaFormateada: _formatearFecha(avistamiento.fecha),
            onQuitar: () => _quitarAvistamiento(avistamiento),
            onReportar: () => _reportarFoto(
              nombre: avistamiento.nombreAve,
              referenciaImagen: avistamiento.rutaImagen,
              origen: 'Avistamiento propio',
            ),
          ),
        ),
        if (fotosVisibles.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'Aves guardadas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ...fotosVisibles.map(
          (foto) => _TarjetaFotoGuardada(
            foto: foto,
            onQuitar: () => _quitarDeColeccion(foto),
            onAbrirFuente: () => _abrirEnlaceFuente(foto.urlArticulo),
            onReportar: () => _reportarFoto(
              nombre: foto.nombre,
              referenciaImagen: foto.urlImagen,
              origen: 'Wikipedia guardada',
            ),
          ),
        ),
        if ((_fotosGuardadas.isNotEmpty || _avistamientosPropios.isNotEmpty) &&
            fotosVisibles.isEmpty &&
            avistamientosVisibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Text(
              'No hay registros que coincidan con estos filtros.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _construirFiltroColeccion({
    required IconData icono,
    required String etiqueta,
    required String seleccionado,
    required List<String> opciones,
    required ValueChanged<String> onSeleccionar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 17, color: _ColoresAves.violeta),
            const SizedBox(width: 7),
            Text(
              etiqueta,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: opciones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final opcion = opciones[index];
              final estaSeleccionada = opcion == seleccionado;
              return ChoiceChip(
                label: Text(opcion),
                selected: estaSeleccionada,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(
                  color: estaSeleccionada
                      ? _ColoresAves.morado
                      : (widget.modoOscuro
                            ? const Color(0xFF51415F)
                            : const Color(0xFFE5D8F5)),
                ),
                backgroundColor: widget.modoOscuro
                    ? const Color(0xFF2B2335)
                    : Colors.white,
                selectedColor: _ColoresAves.morado,
                labelStyle: TextStyle(
                  color: estaSeleccionada
                      ? Colors.white
                      : (widget.modoOscuro
                            ? const Color(0xFFE3D1FF)
                            : _ColoresAves.morado),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                onSelected: (_) => onSeleccionar(opcion),
              );
            },
          ),
        ),
      ],
    );
  }

  String _categoriaAvistamiento(String nombreAve) {
    for (final ave in _catalogo) {
      if (ave.nombre.toLowerCase() == nombreAve.trim().toLowerCase()) {
        return ave.categoria;
      }
    }
    return 'Sin clasificar';
  }

  void _reintentarCargarColeccion() {
    setState(() {
      _cargandoColeccion = true;
      _errorColeccion = null;
    });
    _cargarColeccion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _ColoresAves.amarillo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.flutter_dash_rounded,
                color: _ColoresAves.morado,
                size: 25,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Bitácora de Aves',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_ColoresAves.morado, _ColoresAves.violeta],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              color: _ColoresAves.amarillo,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                onPressed: widget.onAlternarTema,
                tooltip: widget.modoOscuro
                    ? 'Activar modo día'
                    : 'Activar modo noche',
                color: _ColoresAves.morado,
                icon: Icon(
                  widget.modoOscuro
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.modoOscuro
                    ? const [
                        Color(0xFF1E1728),
                        Color(0xFF17131E),
                        Color(0xFF282016),
                      ]
                    : const [
                        Color(0xFFFFFCFF),
                        _ColoresAves.fondo,
                        Color(0xFFFFF9E7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: switch (_indiceSeleccionado) {
              0 => _construirInicio(),
              1 => _construirBusqueda(),
              2 => _construirColeccion(),
              _ => _construirPerfil(),
            },
          ),
          if (_guardandoAvistamiento) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      SizedBox(width: 16),
                      Text('Guardando foto...'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _indiceSeleccionado == 0
          ? FloatingActionButton.extended(
              onPressed: _mostrarOpcionesImagen,
              backgroundColor: _ColoresAves.amarillo,
              foregroundColor: _ColoresAves.morado,
              elevation: 6,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text(
                'Agregar foto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.modoOscuro
                ? const [Color(0xFF342245), Color(0xFF21182D)]
                : const [_ColoresAves.morado, Color(0xFF43206F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'Colección',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
          currentIndex: _indiceSeleccionado,
          selectedItemColor: _ColoresAves.amarillo,
          unselectedItemColor: Colors.white70,
          onTap: _alTocarItem,
        ),
      ),
    );
  }

  Widget _construirPerfil() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 52,
              color: _ColoresAves.violeta,
            ),
            const SizedBox(height: 12),
            const Text(
              'Perfil en preparación',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'Reportes guardados en este dispositivo: '
              '${_reportesFotos.length}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Los reportes aún no se envían al equipo de moderación.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AveWikipedia {
  const _AveWikipedia({
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.urlImagen,
    required this.urlArticulo,
  });

  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String urlImagen;
  final String urlArticulo;
}

class _DatosAvistamiento {
  const _DatosAvistamiento({
    required this.nombreAve,
    required this.lugar,
    required this.fecha,
    required this.comentario,
  });

  final String nombreAve;
  final String lugar;
  final DateTime fecha;
  final String comentario;
}

class _FormularioAvistamientoDialog extends StatefulWidget {
  const _FormularioAvistamientoDialog({required this.formatearFecha});

  final String Function(DateTime) formatearFecha;

  @override
  State<_FormularioAvistamientoDialog> createState() =>
      _FormularioAvistamientoDialogState();
}

class _FormularioAvistamientoDialogState
    extends State<_FormularioAvistamientoDialog> {
  final _formularioKey = GlobalKey<FormState>();
  final _nombreAveController = TextEditingController();
  final _lugarController = TextEditingController();
  final _comentarioController = TextEditingController();
  DateTime? _fechaSeleccionada;

  @override
  void dispose() {
    _nombreAveController.dispose();
    _lugarController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha del avistamiento',
    );
    if (!mounted || fecha == null) return;
    setState(() {
      _fechaSeleccionada = fecha;
    });
  }

  void _guardar() {
    final formularioValido = _formularioKey.currentState?.validate() ?? false;
    if (!formularioValido || _fechaSeleccionada == null) return;

    Navigator.pop(
      context,
      _DatosAvistamiento(
        nombreAve: _nombreAveController.text.trim(),
        lugar: _lugarController.text.trim(),
        fecha: _fechaSeleccionada!,
        comentario: _comentarioController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detalles del avistamiento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formularioKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreAveController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del ave',
                    hintText: 'Ej. Chucao (o "Ave sin identificar")',
                    prefixIcon: Icon(Icons.flutter_dash_rounded),
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Indica el nombre del ave o escribe "Ave sin identificar".'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lugarController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Lugar',
                    hintText: 'Ej. Parque Nacional Conguillío',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Indica dónde observaste el ave.'
                      : null,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _seleccionarFecha,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _fechaSeleccionada == null
                        ? 'Seleccionar fecha'
                        : widget.formatearFecha(_fechaSeleccionada!),
                  ),
                ),
                if (_fechaSeleccionada == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 6),
                    child: Text(
                      'Selecciona la fecha en que viste el ave.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _comentarioController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comentario',
                    hintText: 'Describe brevemente la observación',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Añade un comentario sobre la observación.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardar,
          icon: const Icon(Icons.check),
          label: const Text('Guardar foto'),
        ),
      ],
    );
  }
}

class _DatosReporte {
  const _DatosReporte({required this.motivos, required this.detalle});

  final List<String> motivos;
  final String detalle;
}

class _ReporteFoto {
  const _ReporteFoto({
    required this.nombre,
    required this.referenciaImagen,
    required this.origen,
    required this.motivos,
    required this.detalle,
    required this.fechaCreacion,
  });

  final String nombre;
  final String referenciaImagen;
  final String origen;
  final List<String> motivos;
  final String detalle;
  final String fechaCreacion;

  factory _ReporteFoto.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en el reporte.');
      }
      return dato;
    }

    final motivosJson = json['motivos'];
    if (motivosJson is! List<dynamic> ||
        motivosJson.any((motivo) => motivo is! String)) {
      throw const FormatException('Los motivos del reporte no son válidos.');
    }

    return _ReporteFoto(
      nombre: valor('nombre'),
      referenciaImagen: valor('referenciaImagen'),
      origen: valor('origen'),
      motivos: motivosJson.cast<String>(),
      detalle: json['detalle'] as String? ?? '',
      fechaCreacion: valor('fechaCreacion'),
    );
  }

  Map<String, Object> toJson() => {
    'nombre': nombre,
    'referenciaImagen': referenciaImagen,
    'origen': origen,
    'motivos': motivos,
    'detalle': detalle,
    'fechaCreacion': fechaCreacion,
  };
}

class _BotonReportar extends StatelessWidget {
  const _BotonReportar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Reportar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvistamientoPropio {
  const _AvistamientoPropio({
    required this.nombreAve,
    required this.lugar,
    required this.fecha,
    required this.comentario,
    required this.rutaImagen,
  });

  final String nombreAve;
  final String lugar;
  final DateTime fecha;
  final String comentario;
  final String rutaImagen;

  factory _AvistamientoPropio.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en el avistamiento.');
      }
      return dato;
    }

    return _AvistamientoPropio(
      nombreAve: json['nombreAve'] as String? ?? 'Ave sin identificar',
      lugar: valor('lugar'),
      fecha: DateTime.parse(valor('fecha')),
      comentario: valor('comentario'),
      rutaImagen: valor('rutaImagen'),
    );
  }

  Map<String, String> toJson() => {
    'nombreAve': nombreAve,
    'lugar': lugar,
    'fecha': fecha.toIso8601String(),
    'comentario': comentario,
    'rutaImagen': rutaImagen,
  };
}

class _TarjetaAvistamientoPropio extends StatelessWidget {
  const _TarjetaAvistamientoPropio({
    required this.avistamiento,
    required this.fechaFormateada,
    required this.onQuitar,
    required this.onReportar,
  });

  final _AvistamientoPropio avistamiento;
  final String fechaFormateada;
  final VoidCallback onQuitar;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final modoOscuro = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.file(
                File(avistamiento.rutaImagen),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 240,
                  color: modoOscuro
                      ? const Color(0xFF30263A)
                      : _ColoresAves.lavanda,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _ColoresAves.violeta,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _BotonReportar(onPressed: onReportar),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avistamiento.nombreAve,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: modoOscuro
                        ? const Color(0xFFE3D1FF)
                        : _ColoresAves.morado,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: _ColoresAves.violeta,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        avistamiento.lugar,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: _ColoresAves.violeta,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(fechaFormateada),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  avistamiento.comentario,
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Avistamiento guardado en este dispositivo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onQuitar,
                    style: TextButton.styleFrom(
                      foregroundColor: _ColoresAves.morado,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoGuardada {
  const _FotoGuardada({
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.rutaImagen,
    required this.urlImagen,
    required this.urlArticulo,
  });

  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String rutaImagen;
  final String urlImagen;
  final String urlArticulo;

  factory _FotoGuardada.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en la colección.');
      }
      return dato;
    }

    return _FotoGuardada(
      nombre: valor('nombre'),
      categoria: valor('categoria'),
      nombreCientifico: valor('nombreCientifico'),
      descripcion: valor('descripcion'),
      rutaImagen: valor('rutaImagen'),
      urlImagen: valor('urlImagen'),
      urlArticulo: valor('urlArticulo'),
    );
  }

  Map<String, String> toJson() => {
    'nombre': nombre,
    'categoria': categoria,
    'nombreCientifico': nombreCientifico,
    'descripcion': descripcion,
    'rutaImagen': rutaImagen,
    'urlImagen': urlImagen,
    'urlArticulo': urlArticulo,
  };
}

class _TarjetaFotoGuardada extends StatelessWidget {
  const _TarjetaFotoGuardada({
    required this.foto,
    required this.onQuitar,
    required this.onAbrirFuente,
    required this.onReportar,
  });

  final _FotoGuardada foto;
  final VoidCallback onQuitar;
  final VoidCallback onAbrirFuente;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final modoOscuro = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.file(
                File(foto.rutaImagen),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: modoOscuro
                      ? const Color(0xFF30263A)
                      : _ColoresAves.lavanda,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _ColoresAves.violeta,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _BotonReportar(onPressed: onReportar),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foto.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: modoOscuro
                        ? const Color(0xFFE3D1FF)
                        : _ColoresAves.morado,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  foto.nombreCientifico,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(foto.categoria),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                Text(foto.descripcion),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onAbrirFuente,
                        style: TextButton.styleFrom(
                          foregroundColor: _ColoresAves.morado,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Fuente'),
                      ),
                      TextButton.icon(
                        onPressed: onQuitar,
                        style: TextButton.styleFrom(
                          foregroundColor: _ColoresAves.morado,
                        ),
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        label: const Text('Quitar'),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Imagen de Wikipedia guardada en este dispositivo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAve extends StatelessWidget {
  const _TarjetaAve({
    required this.ave,
    required this.onAbrirArticulo,
    required this.onReportar,
    required this.guardada,
    required this.guardando,
    required this.onGuardar,
    required this.onQuitar,
  });

  final _AveWikipedia ave;
  final VoidCallback onAbrirArticulo;
  final VoidCallback onReportar;
  final bool guardada;
  final bool guardando;
  final VoidCallback onGuardar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final modoOscuro = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                ave.urlImagen,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    color: modoOscuro
                        ? const Color(0xFF30263A)
                        : _ColoresAves.lavanda,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: _ColoresAves.morado,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: modoOscuro
                      ? const Color(0xFF30263A)
                      : _ColoresAves.lavanda,
                  child: const Center(
                    child: Icon(
                      Icons.flutter_dash_rounded,
                      size: 48,
                      color: _ColoresAves.violeta,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _BotonReportar(onPressed: onReportar),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _ColoresAves.morado.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_ColoresAves.amarillo, Color(0xFFFFE88A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ave.categoria,
                    style: const TextStyle(
                      color: _ColoresAves.morado,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Wikipedia',
                    style: TextStyle(
                      color: _ColoresAves.morado,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ave.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: modoOscuro
                        ? const Color(0xFFE3D1FF)
                        : _ColoresAves.morado,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ave.nombreCientifico,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: modoOscuro
                        ? const Color(0xFFB8AFC1)
                        : const Color(0xFF766A83),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ave.descripcion,
                  style: TextStyle(
                    color: modoOscuro
                        ? const Color(0xFFE5DFEB)
                        : const Color(0xFF403A48),
                    height: 1.45,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: guardando
                            ? null
                            : guardada
                            ? onQuitar
                            : onGuardar,
                        icon: guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                guardada
                                    ? Icons.bookmark_remove_outlined
                                    : Icons.bookmark_border_rounded,
                              ),
                        label: Text(guardada ? 'Quitar' : 'Guardar'),
                      ),
                      TextButton.icon(
                        onPressed: onAbrirArticulo,
                        style: TextButton.styleFrom(
                          foregroundColor: _ColoresAves.morado,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Wikipedia'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
