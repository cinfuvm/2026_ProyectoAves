import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/categoria_ave.dart';
import '../models/foto_publica.dart';
import '../services/auth_service.dart';
import '../services/fotos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aparicion_diferida.dart';
import '../widgets/texto_expandible.dart';
import '../widgets/visor_foto.dart';
import 'explorar_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onAlternarTema});

  final VoidCallback onAlternarTema;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _claveColeccion = 'aves_guardadas_catalogo_v1';
  static const _claveColeccionAnterior = 'fotos_guardadas_wikipedia_v1';
  static const _claveAvistamientos = 'avistamientos_propios_v1';
  static const _claveReportes = 'reportes_fotos_pendientes_v1';
  static const _claveSubidasPendientes = 'subidas_bff_pendientes_v1';
  static const _urlBaseAves = 'https://uvm.neocities.org/aves/';
  static const _urlBaseDatosAves = '${_urlBaseAves}fixtures/';
  static const _solicitudesCatalogoPorLote = 12;
  static const _motivosReporte = [
    'La foto no muestra un ave',
    'Contenido inapropiado',
    'La imagen o información es engañosa',
    'Imagen duplicada o de baja calidad',
    'Otro motivo',
  ];

  int _indiceSeleccionado = 0;
  bool _entradaCatalogoPendiente = true;
  final PageController _controladorPaginas = PageController();
  final ImagePicker _selectorImagen = ImagePicker();
  final TextEditingController _controladorBusqueda = TextEditingController();
  final FotosService _fotosServicio = FotosService();
  List<_FotoGuardada> _fotosGuardadas = [];
  List<_AvistamientoPropio> _avistamientosPropios = [];
  List<_ReporteFoto> _reportesFotos = [];
  List<_AveCatalogo> _avesCargadas = [];
  int _fichasCargadas = 0;
  final Set<String> _avesGuardandose = {};
  bool _cargandoColeccion = true;
  bool _guardandoAvistamiento = false;
  String? _errorColeccion;
  String _consulta = '';
  String _categoriaSeleccionada = 'Todas';
  String _filtroTipoColeccion = 'Todo';
  String _filtroCategoriaColeccion = 'Todas';
  String? _nombreInicio;
  final List<FotoPublica> _fotosFeedInicio = [];
  bool _cargandoFeedInicio = true;
  late Future<List<_AveCatalogo>> _aves;

  static const List<String> _tiposColeccion = [
    'Todo',
    'Aves guardadas',
    'Mis avistamientos',
  ];

  @override
  void initState() {
    super.initState();
    _aves = _cargarAves();
    _cargarColeccion();
    _cargarSesionInicio();
    _cargarFeedInicio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recuperarImagenPerdida();
      _reintentarSubidasPendientes();
    });
  }

  Future<void> _cargarSesionInicio() async {
    final usuario = await AuthService().obtenerSesion();
    if (!mounted) return;
    setState(() => _nombreInicio = usuario?.nombre);
  }

  Future<void> _cargarFeedInicio() async {
    try {
      final pagina = await _fotosServicio.getFotos(
        categoria: 'Todas',
        pagina: 0,
        porPagina: 8,
      );
      if (!mounted) return;
      setState(() {
        _fotosFeedInicio
          ..clear()
          ..addAll(pagina.fotos);
        _cargandoFeedInicio = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoFeedInicio = false);
    }
  }

  @override
  void dispose() {
    _controladorPaginas.dispose();
    _controladorBusqueda.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<List<_AveCatalogo>> _cargarAves() async {
    final uriIndice = Uri.parse('${_urlBaseDatosAves}index.json');
    final respuestaIndice = await http
        .get(uriIndice)
        .timeout(const Duration(seconds: 15));
    if (respuestaIndice.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Aves de Chile respondió con estado ${respuestaIndice.statusCode}.',
        uri: uriIndice,
      );
    }

    final jsonIndice = jsonDecode(utf8.decode(respuestaIndice.bodyBytes));
    if (jsonIndice is! List<dynamic>) {
      throw const FormatException(
        'El índice de Aves de Chile no tiene un formato válido.',
      );
    }

    final indice = jsonIndice.map((entrada) {
      if (entrada is! Map<String, dynamic>) {
        throw const FormatException(
          'El índice contiene una ficha de ave no válida.',
        );
      }
      return _EntradaCatalogo.fromJson(entrada);
    }).toList();

    final aves = indice.map((entrada) {
      final base = Uri.parse(_urlBaseAves);
      final urlFicha = base.replace(
        path: '${base.path}bird.html',
        queryParameters: {'id': entrada.uid},
      );
      return _AveCatalogo(
        uid: entrada.uid,
        nombre: entrada.nombre,
        categoria: '',
        nombreCientifico: entrada.nombreCientifico,
        descripcion: '',
        palabrasClave: entrada.palabrasClave,
        urlImagen: _urlImagenAve(entrada.uid, entrada.miniatura),
        urlImagenCompleta: _urlImagenAve(entrada.uid, entrada.imagen),
        urlFicha: urlFicha.toString(),
      );
    }).toList();
    if (mounted) {
      setState(() {
        _avesCargadas = aves;
        _fichasCargadas = 0;
      });
    }

    for (
      var inicio = 0;
      inicio < indice.length;
      inicio += _solicitudesCatalogoPorLote
    ) {
      final fin = (inicio + _solicitudesCatalogoPorLote).clamp(
        0,
        indice.length,
      );
      final lote = indice.sublist(inicio, fin);
      final fichas = await Future.wait(lote.map(_cargarFichaAve));
      for (final ficha in fichas) {
        final indiceAve = aves.indexWhere((ave) => ave.uid == ficha.uid);
        if (indiceAve >= 0) aves[indiceAve] = ficha;
      }
      if (mounted) {
        setState(() {
          _avesCargadas = List<_AveCatalogo>.of(aves);
          _fichasCargadas = fin;
        });
      }
    }

    if (mounted) {
      Future<void>.delayed(const Duration(milliseconds: 1400)).then((_) {
        if (!mounted) return;
        setState(() {
          _entradaCatalogoPendiente = false;
        });
      });
    }

    return aves;
  }

  Future<_AveCatalogo> _cargarFichaAve(_EntradaCatalogo entrada) async {
    final uriFicha = Uri.parse(_urlBaseDatosAves).resolve(entrada.uriDatos);
    final respuesta = await http
        .get(uriFicha)
        .timeout(const Duration(seconds: 15));
    if (respuesta.statusCode != HttpStatus.ok) {
      throw HttpException(
        'La ficha de ${entrada.nombre} respondió con estado '
        '${respuesta.statusCode}.',
        uri: uriFicha,
      );
    }

    final jsonFicha = jsonDecode(utf8.decode(respuesta.bodyBytes));
    if (jsonFicha is! Map<String, dynamic>) {
      throw FormatException('La ficha de ${entrada.nombre} no es válida.');
    }
    final nombres = jsonFicha['names'];
    final acercaDe = jsonFicha['about'];
    final informacion = jsonFicha['info'];
    final multimedia = jsonFicha['media'];
    if (nombres is! Map<String, dynamic> ||
        acercaDe is! Map<String, dynamic> ||
        informacion is! Map<String, dynamic> ||
        multimedia is! Map<String, dynamic>) {
      throw FormatException(
        'La ficha de ${entrada.nombre} no contiene sus datos requeridos.',
      );
    }

    final nombre = nombres['es'];
    final nombreCientifico = nombres['la'];
    final categoria = informacion['order'];
    final imagenCompleta = multimedia['image'];
    if (nombre is! String ||
        nombre.trim().isEmpty ||
        nombreCientifico is! String ||
        nombreCientifico.trim().isEmpty ||
        categoria is! String ||
        categoria.trim().isEmpty ||
        imagenCompleta is! String ||
        !_esNombreArchivoAves(imagenCompleta)) {
      throw FormatException(
        'La ficha de ${entrada.nombre} contiene datos incompletos.',
      );
    }

    final descripcion = acercaDe['description'];
    final imagenMiniatura = multimedia['thumb'];
    final miniatura =
        imagenMiniatura is String && _esNombreArchivoAves(imagenMiniatura)
        ? imagenMiniatura
        : entrada.miniatura;
    final uriBase = Uri.parse(_urlBaseAves);
    final urlFicha = uriBase.replace(
      path: '${uriBase.path}bird.html',
      queryParameters: {'id': entrada.uid},
    );

    return _AveCatalogo(
      uid: entrada.uid,
      nombre: nombre.trim(),
      categoria: categoriaGeneralAves(categoria),
      nombreCientifico: nombreCientifico.trim(),
      descripcion: descripcion is String ? descripcion.trim() : '',
      palabrasClave: entrada.palabrasClave,
      urlImagen: _urlImagenAve(entrada.uid, miniatura),
      urlImagenCompleta: _urlImagenAve(entrada.uid, imagenCompleta),
      urlFicha: urlFicha.toString(),
    );
  }

  String _urlImagenAve(String uid, String nombreArchivo) {
    return Uri.parse(_urlBaseDatosAves)
        .resolve('$uid/$nombreArchivo')
        .toString();
  }

  bool _esNombreArchivoAves(String nombreArchivo) {
    return RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(nombreArchivo);
  }

  Future<void> _cargarColeccion() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardadasJson =
          preferencias.getString(_claveColeccion) ??
          preferencias.getString(_claveColeccionAnterior);
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

  Future<void> _guardarAve(_AveCatalogo ave) async {
    if (_fotosGuardadas.any((foto) => foto.id == ave.uid) ||
        _avesGuardandose.contains(ave.uid)) {
      return;
    }

    setState(() {
      _avesGuardandose.add(ave.uid);
    });

    try {
      final uriImagen = Uri.parse(ave.urlImagenCompleta);
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
          'Aves de Chile no devolvió un archivo de imagen válido.',
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
      final nombreSeguro = ave.uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
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
        urlImagen: ave.urlImagenCompleta,
        id: ave.uid,
        urlFicha: ave.urlFicha,
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
          _avesGuardandose.remove(ave.uid);
        });
      }
    }
  }

  void _mostrarErrorGuardar(String mensaje) {
    _mostrarMensaje('No se pudo guardar el ave: $mensaje');
  }

  Future<bool> _quitarAvistamiento(_AvistamientoPropio avistamiento) async {
    var registroQuitado = false;
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
      registroQuitado = true;

      final archivo = File(avistamiento.rutaImagen);
      if (await archivo.exists()) {
        await archivo.delete();
      }
      _mostrarMensaje('${avistamiento.nombreAve} se quitó de tu bitácora.');
      return true;
    } on FileSystemException catch (error) {
      if (registroQuitado) {
        _mostrarMensaje(
          'El avistamiento se quitó de la bitácora, pero no se pudo borrar '
          'la imagen local: ${error.message}',
        );
        return true;
      }
      _mostrarMensaje('No se pudo actualizar la bitácora: ${error.message}');
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
    return false;
  }

  Future<bool> _quitarDeColeccion(_FotoGuardada foto) async {
    var registroQuitado = false;
    try {
      final nuevasFotos = _fotosGuardadas
          .where((guardada) => guardada.id != foto.id)
          .toList();
      final preferencias = await SharedPreferences.getInstance();
      final guardado = await preferencias.setString(
        _claveColeccion,
        jsonEncode(nuevasFotos.map((guardada) => guardada.toJson()).toList()),
      );
      if (!guardado) {
        throw StateError('No se pudo actualizar la colección.');
      }
      registroQuitado = true;

      final archivo = File(foto.rutaImagen);
      if (await archivo.exists()) {
        await archivo.delete();
      }
      _mostrarMensaje('${foto.nombre} se quitó de tu colección.');
      return true;
    } on FileSystemException catch (error) {
      if (registroQuitado) {
        _mostrarMensaje(
          'El ave se quitó de la colección, pero no se pudo borrar '
          'el archivo local: ${error.message}',
        );
        return true;
      }
      _mostrarErrorColeccion(error.message);
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
    return false;
  }

  void _mostrarErrorColeccion(String mensaje) {
    _mostrarMensaje('No se pudo actualizar la colección: $mensaje');
  }

  void _alTocarItem(int index) {
    if (index == _indiceSeleccionado) return;
    HapticFeedback.selectionClick();
    setState(() {
      _indiceSeleccionado = index;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _controladorPaginas.jumpToPage(index);
      return;
    }
    _controladorPaginas.animateToPage(
      index,
      duration: duracion(context, 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _alCambiarPagina(int index) {
    if (index == _indiceSeleccionado) return;
    HapticFeedback.selectionClick();
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
        nombreCientifico: datos.nombreCientifico,
        categoria: datos.categoria,
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
      unawaited(
        _subirAvistamientoAlBff(rutaImagen: rutaImagen, datos: datos),
      );
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

  String _categoriaBff(String categoria) {
    return switch (categoria) {
      'Terrestres' => 'terrestres',
      'Acuáticas' => 'acuaticas',
      'Rapaces' => 'rapaces',
      'Marinas' => 'marinas',
      'Otras' => 'otras',
      _ => 'otras',
    };
  }

  Future<void> _subirAvistamientoAlBff({
    required String rutaImagen,
    required _DatosAvistamiento datos,
  }) async {
    final token = await AuthService().obtenerToken();
    if (token == null) return;

    final pendiente = <String, String>{
      'rutaImagen': rutaImagen,
      'categoria': _categoriaBff(datos.categoria),
      'lugar': datos.lugar,
      'fecha': datos.fecha.toIso8601String().split('T').first,
      'comentario': datos.comentario,
      'nombreAve': datos.nombreAve,
    };

    final exito = await _intentarSubida(pendiente);
    if (exito) return;

    final preferencias = await SharedPreferences.getInstance();
    final actual = preferencias.getString(_claveSubidasPendientes);
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
    await preferencias.setString(
      _claveSubidasPendientes,
      jsonEncode(lista),
    );
    if (mounted) {
      _mostrarMensaje(
        'Sin conexión con el servidor: la foto se subirá cuando vuelva la conexión.',
      );
    }
  }

  Future<bool> _intentarSubida(Map<String, String> pendiente) async {
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

  Future<void> _reintentarSubidasPendientes() async {
    final token = await AuthService().obtenerToken();
    if (token == null) return;

    final preferencias = await SharedPreferences.getInstance();
    final actual = preferencias.getString(_claveSubidasPendientes);
    if (actual == null) return;

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
      await preferencias.remove(_claveSubidasPendientes);
      return;
    }
    if (lista.isEmpty) return;

    final restantes = <Map<String, String>>[];
    for (final pendiente in lista) {
      final exito = await _intentarSubida(pendiente);
      if (!exito) restantes.add(pendiente);
    }

    if (restantes.isEmpty) {
      await preferencias.remove(_claveSubidasPendientes);
      if (mounted) {
        _mostrarMensaje('Se subieron las fotos que estaban pendientes.');
      }
    } else {
      await preferencias.setString(
        _claveSubidasPendientes,
        jsonEncode(restantes),
      );
    }
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
    String? idFotoRemota,
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

    var enviadoAlServidor = false;
    if (idFotoRemota != null) {
      final exito = await _enviarReporteAlServidor(
        idFoto: idFotoRemota,
        motivos: datos.motivos,
        detalle: datos.detalle,
      );
      enviadoAlServidor = exito;
    }

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
        enviadoAlServidor
            ? 'Reporte enviado a moderación.'
            : 'Reporte guardado en este dispositivo. Se enviará cuando haya conexión con el servidor.',
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

  Future<bool> _enviarReporteAlServidor({
    required String idFoto,
    required List<String> motivos,
    required String detalle,
  }) async {
    try {
      for (final motivo in motivos) {
        final codigo = motivosReporteContrato[motivo] ?? 'otro';
        await _fotosServicio.reportarFoto(
          id: idFoto,
          motivo: codigo,
          detalle: codigo == 'otro' || detalle.isNotEmpty
              ? (detalle.isEmpty ? motivo : detalle)
              : null,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _mostrarErrorReporte(String mensaje) {
    _mostrarMensaje('No se pudo registrar el reporte: $mensaje');
  }

  Future<void> _abrirFicha(_AveCatalogo ave) async {
    await _abrirEnlaceFuente(ave.urlFicha);
  }

  Future<void> _abrirEnlaceFuente(String url) async {
    final abierto = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto) {
      _mostrarMensaje('No se pudo abrir la ficha de Aves de Chile.');
    }
  }

  Widget _construirInicio() {
    final avistamientosRecientes = _avistamientosPropios.take(5).toList();
    final fotosComunidad = _fotosFeedInicio.take(8).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
      children: [
        _construirEncabezadoInicio(),
        const SizedBox(height: 14),
        _construirTiraResumen(),
        const SizedBox(height: 28),
        if (avistamientosRecientes.isEmpty)
          _tarjetaVaciaInicio(
            icono: Icons.camera_alt_outlined,
            titulo: 'Aún no tienes avistamientos',
            mensaje: 'Agrega tu primera foto y guarda dónde la encontraste.',
            accion: 'Agregar foto',
            onAccion: _mostrarOpcionesImagen,
          )
        else ...[
          _construirEncabezadoSeccion(
            titulo: 'Tus últimos avistamientos',
            onVerTodo: () => _alTocarItem(3),
            etiquetaVerTodo: 'Ver colección',
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avistamientosRecientes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final avistamiento = avistamientosRecientes[index];
                return _TarjetaAvistamientoReciente(
                  avistamiento: avistamiento,
                  fechaFormateada: _formatearFecha(avistamiento.fecha),
                  onAbrir: () => _alTocarItem(3),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 28),
        if (_cargandoFeedInicio)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: PaletaAves.morado),
            ),
          )
        else if (fotosComunidad.isEmpty)
          _tarjetaVaciaInicio(
            icono: Icons.explore_outlined,
            titulo: 'La comunidad está tranquila por ahora',
            mensaje:
                'Cuando la gente publique fotos aparecerán aquí. '
                'Mientras tanto, explora las aves de Chile.',
            accion: 'Explorar ahora',
            onAccion: () => _alTocarItem(2),
          )
        else ...[
          _construirEncabezadoSeccion(
            titulo: 'Recién en la comunidad',
            onVerTodo: () => _alTocarItem(2),
            etiquetaVerTodo: 'Ver todo',
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotosComunidad.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final foto = fotosComunidad[index];
                return _TarjetaFotoComunidad(
                  foto: foto,
                  onAbrir: () => _alTocarItem(2),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 28),
        _construirEncabezadoSeccion(titulo: 'Descubre más'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _tarjetaAccesoRapido(
                icono: Icons.search_rounded,
                titulo: 'Buscar aves',
                mensaje: 'Catálogo de 216 especies de Chile.',
                onAccion: () => _alTocarItem(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaAccesoRapido(
                icono: Icons.explore_rounded,
                titulo: 'Comunidad',
                mensaje: 'Fotos de observadores como tú.',
                onAccion: () => _alTocarItem(2),
                destacado: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirEncabezadoInicio() {
    final marca = context.marca;
    final esApaisada =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 600;
    final saludo = _nombreInicio == null || _nombreInicio!.isEmpty
        ? 'Hola, observador'
        : 'Hola, ${_nombreInicio!}';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esApaisada ? 16 : 22),
      decoration: BoxDecoration(
        gradient: marca.cabeceraGradiente,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  saludo,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: esApaisada ? 24 : 30,
                    height: 1.1,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pequeños encuentros, grandes historias.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 64,
                  height: 5,
                  decoration: BoxDecoration(
                    color: PaletaAves.amarillo,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: esApaisada ? 56 : 84,
            height: esApaisada ? 56 : 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.flutter_dash_rounded,
              size: esApaisada ? 34 : 50,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTiraResumen() {
    Widget dato({
      required IconData icono,
      required int valor,
      required String etiqueta,
    }) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              '$valor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: context.marca.barraGradiente,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          dato(
            icono: Icons.camera_alt_rounded,
            valor: _avistamientosPropios.length,
            etiqueta: _avistamientosPropios.length == 1
                ? 'Avistamiento'
                : 'Avistamientos',
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          dato(
            icono: Icons.bookmark_rounded,
            valor: _fotosGuardadas.length,
            etiqueta: _fotosGuardadas.length == 1
                ? 'Ave guardada'
                : 'Aves guardadas',
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezadoSeccion({
    required String titulo,
    VoidCallback? onVerTodo,
    String etiquetaVerTodo = 'Ver todo',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10, bottom: 1),
            decoration: BoxDecoration(
              color: PaletaAves.amarillo,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (onVerTodo != null)
            TextButton(
              onPressed: onVerTodo,
              style: TextButton.styleFrom(
                foregroundColor: PaletaAves.violeta,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(etiquetaVerTodo),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaVaciaInicio({
    required IconData icono,
    required String titulo,
    required String mensaje,
    required String accion,
    required VoidCallback onAccion,
  }) {
    final marca = context.marca;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: _formaTarjetaAve(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 36, color: marca.iconoMarca),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(mensaje, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAccion,
              style: FilledButton.styleFrom(
                backgroundColor: PaletaAves.morado,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(accion),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaAccesoRapido({
    required IconData icono,
    required String titulo,
    required String mensaje,
    required VoidCallback onAccion,
    bool destacado = false,
  }) {
    final iconoColor = destacado ? PaletaAves.morado : Colors.white;
    final fondoIcono = destacado
        ? PaletaAves.amarillo
        : Colors.white.withValues(alpha: 0.18);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onAccion,
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: destacado
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PaletaAves.morado, PaletaAves.violeta],
                  ),
            color: destacado ? PaletaAves.amarillo : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icono, color: iconoColor, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: destacado ? PaletaAves.morado : Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mensaje,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: destacado
                      ? PaletaAves.morado.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.88),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBusqueda() {
    return _construirCatalogo();
  }

  Widget _construirCatalogo() {
    return FutureBuilder<List<_AveCatalogo>>(
      future: _aves,
      builder: (context, snapshot) {
        final aves = snapshot.data ?? _avesCargadas;
        if (snapshot.connectionState == ConnectionState.waiting &&
            aves.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: PaletaAves.morado),
          );
        }
        if (snapshot.hasError && aves.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_outlined,
                    size: 48,
                    color: PaletaAves.violeta,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las aves de Chile. '
                    'Revisa tu conexión e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _aves = _cargarAves();
                        _entradaCatalogoPendiente = true;
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

        final categorias = [
          'Todas',
          ...aves
              .map((ave) => ave.categoria)
              .where((categoria) => categoria.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        ];
        final avesVisibles = aves.where((ave) {
          final consulta = _consulta.toLowerCase().trim();
          final coincideCategoria =
              _categoriaSeleccionada == 'Todas' ||
              ave.categoria == _categoriaSeleccionada;
          final coincideTexto =
              consulta.isEmpty ||
              ave.nombre.toLowerCase().contains(consulta) ||
              ave.nombreCientifico.toLowerCase().contains(consulta) ||
              ave.descripcion.toLowerCase().contains(consulta) ||
              ave.palabrasClave.toLowerCase().contains(consulta);
          return coincideCategoria && coincideTexto;
        }).toList();

        final contenidoFijo = <Widget>[
          _construirEncabezadoBusqueda(),
        ];
        if (snapshot.connectionState == ConnectionState.waiting) {
          contenidoFijo.addAll([
            Text('Cargando fichas: $_fichasCargadas de ${aves.length}'),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _fichasCargadas / aves.length),
            const SizedBox(height: 12),
          ]);
        }
        if (snapshot.hasError) {
          contenidoFijo.addAll([
            Text(
              'No se completó la carga de todas las fichas. '
              'Puedes reintentar.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _avesCargadas = [];
                    _fichasCargadas = 0;
                    _aves = _cargarAves();
                    _entradaCatalogoPendiente = true;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar carga'),
              ),
            ),
          ]);
        }
        contenidoFijo.addAll([
          const SizedBox(height: 16),
          TextField(
            controller: _controladorBusqueda,
            onChanged: (valor) => setState(() => _consulta = valor),
            decoration: InputDecoration(
              hintText: 'Nombre común o científico',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: AnimatedSwitcher(
                duration: duracion(context, 150),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (hijo, anim) =>
                    FadeTransition(opacity: anim, child: hijo),
                child: _consulta.isEmpty
                    ? const SizedBox.shrink(
                        key: ValueKey<String>('sin-consulta'),
                      )
                    : IconButton(
                        key: const ValueKey<String>('limpiar-consulta'),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _controladorBusqueda.clear();
                          setState(() => _consulta = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
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
              itemCount: categorias.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final categoria = categorias[index];
                final marca = context.marca;
                return ChoiceChip(
                  label: Text(categoria),
                  selected: _categoriaSeleccionada == categoria,
                  selectedColor: PaletaAves.morado,
                  backgroundColor: marca.chipFondo,
                  labelStyle: TextStyle(
                    color: _categoriaSeleccionada == categoria
                        ? Colors.white
                        : marca.chipTexto,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: _categoriaSeleccionada == categoria
                        ? PaletaAves.morado
                        : marca.chipBorde,
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
          const SizedBox(height: 16),
        ]);
        if (avesVisibles.isEmpty) {
          contenidoFijo.add(
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No encontramos aves con esos filtros.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          itemCount: contenidoFijo.length + avesVisibles.length,
          itemBuilder: (context, index) {
            if (index < contenidoFijo.length) return contenidoFijo[index];

            final indiceAve = index - contenidoFijo.length;
            final ave = avesVisibles[indiceAve];
            return AparicionDiferida(
              key: ValueKey<String>(ave.uid),
              indice: indiceAve,
              activa: _entradaCatalogoPendiente,
              child: _TarjetaAve(
                ave: ave,
                onAbrirFicha: () => _abrirFicha(ave),
                onReportar: () => _reportarFoto(
                  nombre: ave.nombre,
                  referenciaImagen: ave.urlImagen,
                  origen: 'Aves de Chile',
                ),
                guardada: _fotosGuardadas.any((foto) => foto.id == ave.uid),
                guardando: _avesGuardandose.contains(ave.uid),
                onGuardar: () => _guardarAve(ave),
                onQuitar: () {
                  final fotosGuardadas = _fotosGuardadas.where(
                    (foto) => foto.id == ave.uid,
                  );
                  if (fotosGuardadas.isNotEmpty) {
                    final foto = fotosGuardadas.first;
                    _quitarDeColeccion(foto).then((quitada) {
                      if (!quitada || !mounted) return;
                      setState(() {
                        _fotosGuardadas = _fotosGuardadas
                            .where((guardada) => guardada.id != foto.id)
                            .toList();
                      });
                    });
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirEncabezadoBusqueda() {
    final marca = context.marca;
    final esApaisada =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esApaisada ? 14 : 20),
      decoration: BoxDecoration(
        gradient: marca.cabeceraGradiente,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PaletaAves.morado.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: esApaisada
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explora y descubre',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encuentra tu próxima ave favorita.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PaletaAves.amarillo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 76,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explora y descubre',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Encuentra tu próxima ave favorita.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PaletaAves.amarillo,
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
        child: CircularProgressIndicator(color: PaletaAves.morado),
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
                color: PaletaAves.violeta,
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

    final categoriasDisponibles = <String>{
      ..._avesCargadas.map((ave) => categoriaGeneralAves(ave.categoria)),
      ..._fotosGuardadas.map((foto) => categoriaGeneralAves(foto.categoria)),
      ..._avistamientosPropios.map(_categoriaAvistamiento),
    }..removeWhere((categoria) => categoria.trim().isEmpty);
    categoriasDisponibles.remove('Todas');
    final categoriasColeccion = [
      'Todas',
      ...categoriasDisponibles.toList()..sort(),
    ];

    final fotosVisibles = _filtroTipoColeccion == 'Mis avistamientos'
        ? const <_FotoGuardada>[]
        : _fotosGuardadas.where((foto) {
            return _filtroCategoriaColeccion == 'Todas' ||
                foto.categoria == _filtroCategoriaColeccion;
          }).toList();
    final avistamientosVisibles = _filtroTipoColeccion == 'Aves guardadas'
        ? const <_AvistamientoPropio>[]
        : _avistamientosPropios.where((avistamiento) {
            final categoria = _categoriaAvistamiento(avistamiento);
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
                opciones: categoriasColeccion,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 48,
                  color: context.marca.iconoMarca,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu colección está vacía',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Guarda aves del catálogo o agrega una foto con sus datos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (avistamientosVisibles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Avistamientos propios',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ...avistamientosVisibles.map(
          (avistamiento) => _TarjetaConSalida(
            key: ValueKey<String>('avistamiento:${avistamiento.rutaImagen}'),
            eliminar: () => _quitarAvistamiento(avistamiento),
            alEliminar: () {
              if (!mounted) return;
              setState(() {
                _avistamientosPropios = _avistamientosPropios
                    .where((item) => item.rutaImagen != avistamiento.rutaImagen)
                    .toList();
              });
            },
            construir: (onQuitar, quitando) => _TarjetaAvistamientoPropio(
              avistamiento: avistamiento,
              fechaFormateada: _formatearFecha(avistamiento.fecha),
              onQuitar: onQuitar,
              quitando: quitando,
              onReportar: () => _reportarFoto(
                nombre: avistamiento.nombreAve,
                referenciaImagen: avistamiento.rutaImagen,
                origen: 'Avistamiento propio',
              ),
            ),
          ),
        ),
        if (fotosVisibles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'Aves guardadas',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ...fotosVisibles.map(
          (foto) => _TarjetaConSalida(
            key: ValueKey<String>('guardada:${foto.id}'),
            eliminar: () => _quitarDeColeccion(foto),
            alEliminar: () {
              if (!mounted) return;
              setState(() {
                _fotosGuardadas = _fotosGuardadas
                    .where((guardada) => guardada.id != foto.id)
                    .toList();
              });
            },
            construir: (onQuitar, quitando) => _TarjetaFotoGuardada(
              foto: foto,
              onQuitar: onQuitar,
              quitando: quitando,
              onAbrirFicha: foto.urlFicha == null
                  ? null
                  : () => _abrirEnlaceFuente(foto.urlFicha!),
              onReportar: () => _reportarFoto(
                nombre: foto.nombre,
                referenciaImagen: foto.urlImagen,
                origen: 'Aves de Chile guardada',
              ),
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
            Icon(icono, size: 17, color: PaletaAves.violeta),
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
              final marca = context.marca;
              return ChoiceChip(
                label: Text(opcion),
                selected: estaSeleccionada,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(
                  color: estaSeleccionada ? PaletaAves.morado : marca.chipBorde,
                ),
                backgroundColor: marca.chipFondo,
                selectedColor: PaletaAves.morado,
                labelStyle: TextStyle(
                  color: estaSeleccionada ? Colors.white : marca.chipTexto,
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

  String _categoriaAvistamiento(_AvistamientoPropio avistamiento) {
    final categoria = avistamiento.categoria.trim();
    if (categoria.isNotEmpty) return categoriaGeneralAves(categoria);

    final nombreAve = avistamiento.nombreAve.trim().toLowerCase();
    final nombreCientifico = avistamiento.nombreCientifico.trim().toLowerCase();
    for (final ave in _avesCargadas) {
      if (ave.nombre.toLowerCase() == nombreAve ||
          (nombreCientifico.isNotEmpty &&
              ave.nombreCientifico.toLowerCase() == nombreCientifico)) {
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
    final marca = context.marca;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final esApaisada =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final usaRail = anchoPantalla >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: PaletaAves.amarillo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.flutter_dash_rounded,
                color: PaletaAves.morado,
                size: 25,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Bitácora de Aves'),
          ],
        ),
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
        actions: [
          if (esApaisada && _indiceSeleccionado == 0)
            IconButton(
              onPressed: _mostrarOpcionesImagen,
              tooltip: 'Agregar foto',
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Material(
              color: PaletaAves.amarillo,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                onPressed: widget.onAlternarTema,
                tooltip: esOscuro ? 'Activar modo día' : 'Activar modo noche',
                color: PaletaAves.morado,
                icon: AnimatedSwitcher(
                  duration: duracion(context, 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (hijo, anim) => FadeTransition(
                    opacity: anim,
                    child: RotationTransition(
                      turns: Tween<double>(begin: -0.25, end: 0).animate(anim),
                      child: hijo,
                    ),
                  ),
                  child: Icon(
                    esOscuro
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(esOscuro),
                  ),
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
          Row(
            children: [
              if (usaRail)
                DecoratedBox(
                  decoration: BoxDecoration(gradient: marca.barraGradiente),
                  child: NavigationRail(
                    selectedIndex: _indiceSeleccionado,
                    onDestinationSelected: _alTocarItem,
                    backgroundColor: Colors.transparent,
                    labelType: NavigationRailLabelType.all,
                    scrollable: true,
                    destinations: const <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Inicio'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search),
                        label: Text('Buscar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.explore_outlined),
                        selectedIcon: Icon(Icons.explore),
                        label: Text('Explorar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.library_books_outlined),
                        selectedIcon: Icon(Icons.library_books),
                        label: Text('Colección'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Perfil'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: marca.fondoGradiente),
                  child: PageView.builder(
                    controller: _controladorPaginas,
                    itemCount: 5,
                    onPageChanged: _alCambiarPagina,
                    itemBuilder: (context, index) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: switch (index) {
                          0 => _construirInicio(),
                          1 => _construirBusqueda(),
                          2 => _construirExplorar(),
                          3 => _construirColeccion(),
                          _ => _construirPerfil(),
                        },
                      ),
                    ),
                    physics: const PageScrollPhysics(),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: duracion(context, 200),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (hijo, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
                child: hijo,
              ),
            ),
            child: _guardandoAvistamiento
                ? const KeyedSubtree(
                    key: ValueKey<String>('guardando-avistamiento'),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ModalBarrier(dismissible: false, color: Colors.black26),
                        Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Guardando foto...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: duracion(context, 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (hijo, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
            child: hijo,
          ),
        ),
        child: _indiceSeleccionado == 0 && !esApaisada
            ? KeyedSubtree(
                key: const ValueKey<String>('fab-agregar-foto'),
                child: FloatingActionButton.extended(
                  onPressed: _mostrarOpcionesImagen,
                  backgroundColor: PaletaAves.amarillo,
                  foregroundColor: PaletaAves.morado,
                  elevation: 6,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text(
                    'Agregar foto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : null,
      ),
      bottomNavigationBar: usaRail
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(gradient: marca.barraGradiente),
              child: NavigationBar(
                selectedIndex: _indiceSeleccionado,
                onDestinationSelected: _alTocarItem,
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    label: 'Buscar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: 'Explorar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_books),
                    label: 'Colección',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Perfil',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _construirExplorar() {
    return ExplorarScreen(
      idsGuardados: _fotosGuardadas.map((foto) => foto.id).toSet(),
      onGuardar: _guardarFotoComunidad,
      onReportar: (foto) => _reportarFoto(
        nombre: foto.autor ?? 'Observador',
        referenciaImagen: foto.url,
        origen: 'Explorar',
        idFotoRemota: foto.id,
      ),
    );
  }

  Future<void> _guardarFotoComunidad(FotoPublica foto) async {
    if (_fotosGuardadas.any((guardada) => guardada.id == foto.id) ||
        _avesGuardandose.contains(foto.id)) {
      return;
    }

    setState(() {
      _avesGuardandose.add(foto.id);
    });

    try {
      final uriImagen = Uri.parse(foto.url);
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
          !(respuesta.headers['content-type']?.startsWith('image/') ??
              false)) {
        throw const FormatException(
          'El servidor no devolvió un archivo de imagen válido.',
        );
      }

      final directorioApp = await getApplicationDocumentsDirectory();
      final directorioColeccion = Directory(
        '${directorioApp.path}${Platform.pathSeparator}coleccion_aves',
      );
      await directorioColeccion.create(recursive: true);

      final nombreArchivoFuente = uriImagen.pathSegments.isEmpty
          ? 'foto.jpg'
          : uriImagen.pathSegments.last;
      final extension =
          RegExp(
            r'\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ).firstMatch(nombreArchivoFuente)?.group(0)?.toLowerCase() ??
          '.jpg';
      final nombreSeguro = foto.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final nombreArchivo =
          '${nombreSeguro}_${DateTime.now().microsecondsSinceEpoch}$extension';
      final rutaImagen =
          '${directorioColeccion.path}${Platform.pathSeparator}$nombreArchivo';
      final archivoTemporal = File('$rutaImagen.tmp');
      await archivoTemporal.writeAsBytes(respuesta.bodyBytes, flush: true);
      await archivoTemporal.rename(rutaImagen);

      final fotoGuardada = _FotoGuardada(
        id: foto.id,
        nombre: foto.autor ?? 'Observador',
        categoria: foto.categoria,
        nombreCientifico: foto.lugar ?? '',
        descripcion: foto.comentario ?? '',
        rutaImagen: rutaImagen,
        urlImagen: foto.url,
        urlFicha: null,
        esDeComunidad: true,
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
      _mostrarMensaje('Foto de ${foto.autor ?? 'la comunidad'} guardada.');
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
          _avesGuardandose.remove(foto.id);
        });
      }
    }
  }

  Widget _construirPerfil() {
    return PerfilScreen(reportesGuardados: _reportesFotos.length);
  }
}

class _EntradaCatalogo {
  const _EntradaCatalogo({
    required this.uid,
    required this.uriDatos,
    required this.nombre,
    required this.nombreCientifico,
    required this.palabrasClave,
    required this.miniatura,
    required this.imagen,
  });

  final String uid;
  final String uriDatos;
  final String nombre;
  final String nombreCientifico;
  final String palabrasClave;
  final String miniatura;
  final String imagen;

  factory _EntradaCatalogo.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    final uriDatos = json['uri'];
    final palabrasClave = json['keywords'];
    final miniatura = json['thumb'];
    final imagen = json['image'];
    final nombres = json['names'];
    if (uid is! String ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(uid) ||
        uriDatos is! String ||
        palabrasClave is! String ||
        miniatura is! String ||
        imagen is! String ||
        nombres is! Map<String, dynamic>) {
      throw const FormatException(
        'Una entrada del catálogo contiene campos inválidos.',
      );
    }

    final referenciaDatos = Uri.parse(uriDatos);
    final segmentosUri = referenciaDatos.pathSegments;
    final nombre = nombres['es'];
    final nombreCientifico = nombres['la'];
    if (nombre is! String ||
        nombre.trim().isEmpty ||
        nombreCientifico is! String ||
        nombreCientifico.trim().isEmpty ||
        segmentosUri.length != 2 ||
        segmentosUri.first != uid ||
        segmentosUri.last != 'data.json' ||
        referenciaDatos.hasScheme ||
        referenciaDatos.hasAuthority ||
        referenciaDatos.hasQuery ||
        referenciaDatos.hasFragment ||
        referenciaDatos.path.startsWith('/') ||
        !_esNombreArchivoCatalogo(miniatura) ||
        !_esNombreArchivoCatalogo(imagen)) {
      throw FormatException('La entrada de catálogo "$uid" está incompleta.');
    }

    return _EntradaCatalogo(
      uid: uid,
      uriDatos: uriDatos,
      nombre: nombre.trim(),
      nombreCientifico: nombreCientifico.trim(),
      palabrasClave: palabrasClave,
      miniatura: miniatura,
      imagen: imagen,
    );
  }

  static bool _esNombreArchivoCatalogo(String valor) =>
      RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(valor);
}

class _AveCatalogo {
  const _AveCatalogo({
    required this.uid,
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.palabrasClave,
    required this.urlImagen,
    required this.urlImagenCompleta,
    required this.urlFicha,
  });

  final String uid;
  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String palabrasClave;
  final String urlImagen;
  final String urlImagenCompleta;
  final String urlFicha;
}

class _DatosAvistamiento {
  const _DatosAvistamiento({
    required this.nombreAve,
    required this.nombreCientifico,
    required this.categoria,
    required this.lugar,
    required this.fecha,
    required this.comentario,
  });

  final String nombreAve;
  final String nombreCientifico;
  final String categoria;
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
  final _nombreCientificoController = TextEditingController();
  final _lugarController = TextEditingController();
  final _comentarioController = TextEditingController();
  DateTime? _fechaSeleccionada;
  String? _categoriaSeleccionada;

  @override
  void dispose() {
    _nombreAveController.dispose();
    _nombreCientificoController.dispose();
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
        nombreCientifico: _nombreCientificoController.text.trim(),
        categoria: _categoriaSeleccionada ?? '',
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
                  controller: _nombreCientificoController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre científico (opcional)',
                    hintText: 'Ej. Nothoprocta perdicaria',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _categoriaSeleccionada,
                  onChanged: (categoria) {
                    setState(() {
                      _categoriaSeleccionada = categoria;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Categoría (opcional)',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categoriasGeneralesAves
                      .map(
                        (categoria) => DropdownMenuItem<String>(
                          value: categoria,
                          child: Text(categoria),
                        ),
                      )
                      .toList(),
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
    required this.nombreCientifico,
    required this.categoria,
    required this.lugar,
    required this.fecha,
    required this.comentario,
    required this.rutaImagen,
  });

  final String nombreAve;
  final String nombreCientifico;
  final String categoria;
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

    String valorOpcional(String clave) {
      final dato = json[clave];
      return dato is String ? dato : '';
    }

    return _AvistamientoPropio(
      nombreAve: json['nombreAve'] as String? ?? 'Ave sin identificar',
      nombreCientifico: valorOpcional('nombreCientifico'),
      categoria: categoriaGeneralAves(valorOpcional('categoria')),
      lugar: valor('lugar'),
      fecha: DateTime.parse(valor('fecha')),
      comentario: valor('comentario'),
      rutaImagen: valor('rutaImagen'),
    );
  }

  Map<String, String> toJson() => {
    'nombreAve': nombreAve,
    'nombreCientifico': nombreCientifico,
    'categoria': categoria,
    'lugar': lugar,
    'fecha': fecha.toIso8601String(),
    'comentario': comentario,
    'rutaImagen': rutaImagen,
  };
}

class _TarjetaConSalida extends StatefulWidget {
  const _TarjetaConSalida({
    super.key,
    required this.construir,
    required this.eliminar,
    required this.alEliminar,
  });

  final Widget Function(VoidCallback onQuitar, bool quitando) construir;
  final Future<bool> Function() eliminar;
  final VoidCallback alEliminar;

  @override
  State<_TarjetaConSalida> createState() => _TarjetaConSalidaState();
}

class _TarjetaConSalidaState extends State<_TarjetaConSalida> {
  bool _quitando = false;
  bool _saliendo = false;

  Future<void> _eliminar() async {
    if (_quitando || _saliendo) return;
    final eliminar = widget.eliminar;
    final alEliminar = widget.alEliminar;
    setState(() {
      _quitando = true;
    });

    final eliminado = await eliminar();
    if (!eliminado) {
      if (mounted) {
        setState(() {
          _quitando = false;
        });
      }
      return;
    }
    if (!mounted) {
      alEliminar();
      return;
    }

    setState(() {
      _saliendo = true;
    });
    await Future<void>.delayed(duracion(context, 220));
    alEliminar();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: _saliendo ? 0 : 1),
      duration: duracion(context, 220),
      curve: Curves.easeInOutCubic,
      builder: (context, avance, child) {
        final direccion = Directionality.of(context) == TextDirection.ltr
            ? 1.0
            : -1.0;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: avance,
            child: Opacity(
              opacity: avance,
              child: Transform.translate(
                offset: Offset(direccion * 14 * (1 - avance), 0),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.construir(_eliminar, _quitando),
    );
  }
}

class _TarjetaAvistamientoPropio extends StatelessWidget {
  const _TarjetaAvistamientoPropio({
    required this.avistamiento,
    required this.fechaFormateada,
    required this.onQuitar,
    required this.quitando,
    required this.onReportar,
  });

  final _AvistamientoPropio avistamiento;
  final String fechaFormateada;
  final VoidCallback onQuitar;
  final bool quitando;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'avist:${avistamiento.rutaImagen}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: _formaTarjetaAve(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => mostrarVisorFoto(
                  context,
                  etiquetaHero: etiquetaHero,
                  titulo: avistamiento.nombreAve,
                  subtitulo: null,
                  construirImagen: (_) => Image.file(
                    File(avistamiento.rutaImagen),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Hero(
                  tag: etiquetaHero,
                  child: Image.file(
                    File(avistamiento.rutaImagen),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 240,
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
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
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (avistamiento.nombreCientifico.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    avistamiento.nombreCientifico,
                    style: GoogleFonts.fraunces(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: marca.textoCientifico,
                    ),
                  ),
                ],
                if (avistamiento.categoria.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: PaletaAves.morado,
                    ),
                    label: Text(avistamiento.categoria),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: marca.chipBorde),
                    backgroundColor: marca.chipFondo,
                    labelStyle: TextStyle(color: marca.chipTexto),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: PaletaAves.violeta,
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
                      color: PaletaAves.violeta,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(fechaFormateada),
                  ],
                ),
                const SizedBox(height: 12),
                TextoExpandible(
                  texto: avistamiento.comentario,
                  estilo: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  'Avistamiento guardado en este dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: marca.textoSecundario),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: quitando ? null : onQuitar,
                    style: TextButton.styleFrom(
                      foregroundColor: PaletaAves.morado,
                    ),
                    icon: quitando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(quitando ? 'Quitando…' : 'Quitar'),
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
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.nombreCientifico,
    required this.descripcion,
    required this.rutaImagen,
    required this.urlImagen,
    required this.urlFicha,
    this.esDeComunidad = false,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String nombreCientifico;
  final String descripcion;
  final String rutaImagen;
  final String urlImagen;
  final String? urlFicha;
  final bool esDeComunidad;

  factory _FotoGuardada.fromJson(Map<String, dynamic> json) {
    String valor(String clave) {
      final dato = json[clave];
      if (dato is! String || dato.isEmpty) {
        throw FormatException('Falta el campo "$clave" en la colección.');
      }
      return dato;
    }

    String valorOpcional(String clave) {
      final dato = json[clave];
      return dato is String ? dato : '';
    }

    final id = json['id'];
    final urlFicha = json['urlFicha'];
    return _FotoGuardada(
      id: id is String && id.isNotEmpty ? id : valor('urlArticulo'),
      nombre: valor('nombre'),
      categoria: categoriaGeneralAves(valorOpcional('categoria')),
      nombreCientifico: valorOpcional('nombreCientifico'),
      descripcion: valorOpcional('descripcion'),
      rutaImagen: valor('rutaImagen'),
      urlImagen: valor('urlImagen'),
      urlFicha: urlFicha is String && urlFicha.isNotEmpty ? urlFicha : null,
      esDeComunidad: json['esDeComunidad'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoria': categoria,
    'nombreCientifico': nombreCientifico,
    'descripcion': descripcion,
    'rutaImagen': rutaImagen,
    'urlImagen': urlImagen,
    'urlFicha': urlFicha,
    if (esDeComunidad) 'esDeComunidad': true,
  };
}

class _TarjetaFotoGuardada extends StatelessWidget {
  const _TarjetaFotoGuardada({
    required this.foto,
    required this.onQuitar,
    required this.quitando,
    required this.onAbrirFicha,
    required this.onReportar,
  });

  final _FotoGuardada foto;
  final VoidCallback onQuitar;
  final bool quitando;
  final VoidCallback? onAbrirFicha;
  final VoidCallback onReportar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'foto:${foto.id}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: _formaTarjetaAve(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => mostrarVisorFoto(
                  context,
                  etiquetaHero: etiquetaHero,
                  titulo: foto.nombre,
                  subtitulo: foto.nombreCientifico,
                  construirImagen: (_) => Image.file(
                    File(foto.rutaImagen),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                child: Hero(
                  tag: etiquetaHero,
                  child: Image.file(
                    File(foto.rutaImagen),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 220,
                      color: marca.placeholder,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: PaletaAves.violeta,
                          size: 48,
                        ),
                      ),
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
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  foto.nombreCientifico,
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: marca.textoCientifico,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(foto.categoria),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                TextoExpandible(texto: foto.descripcion),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      if (onAbrirFicha != null)
                        TextButton.icon(
                          onPressed: onAbrirFicha,
                          style: TextButton.styleFrom(
                            foregroundColor: PaletaAves.morado,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Aves de Chile'),
                        ),
                      TextButton.icon(
                        onPressed: quitando ? null : onQuitar,
                        style: TextButton.styleFrom(
                          foregroundColor: PaletaAves.morado,
                        ),
                        icon: quitando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bookmark_remove_outlined),
                        label: Text(quitando ? 'Quitando…' : 'Quitar'),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Imagen guardada en este dispositivo.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: marca.textoSecundario),
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
    required this.onAbrirFicha,
    required this.onReportar,
    required this.guardada,
    required this.guardando,
    required this.onGuardar,
    required this.onQuitar,
  });

  final _AveCatalogo ave;
  final VoidCallback onAbrirFicha;
  final VoidCallback onReportar;
  final bool guardada;
  final bool guardando;
  final VoidCallback onGuardar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    final etiquetaHero = 'ave:${ave.uid}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: _formaTarjetaAve(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esApaisada =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 640;
          final alturaImagen = esApaisada ? 180.0 : 220.0;
          final anchoImagen = esApaisada
              ? (constraints.maxWidth * 0.36).clamp(200.0, 260.0).toDouble()
              : constraints.maxWidth;
          final imagen = SizedBox(
            width: anchoImagen,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => mostrarVisorFoto(
                    context,
                    etiquetaHero: etiquetaHero,
                    titulo: ave.nombre,
                    subtitulo: ave.nombreCientifico,
                    construirImagen: (_) => Image.network(
                      ave.urlImagen,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: marca.placeholder,
                        child: const Center(
                          child: Icon(
                            Icons.flutter_dash_rounded,
                            size: 48,
                            color: PaletaAves.violeta,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: etiquetaHero,
                    child: Image.network(
                      ave.urlImagen,
                      height: alturaImagen,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (anchoImagen * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: alturaImagen,
                          color: marca.placeholder,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: PaletaAves.morado,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: alturaImagen,
                        color: marca.placeholder,
                        child: const Center(
                          child: Icon(
                            Icons.flutter_dash_rounded,
                            size: 48,
                            color: PaletaAves.violeta,
                          ),
                        ),
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
                          PaletaAves.morado.withValues(alpha: 0.72),
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
                        colors: [PaletaAves.amarillo, Color(0xFFFFE88A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ave.categoria,
                      style: const TextStyle(
                        color: PaletaAves.morado,
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
                      'Aves de Chile',
                      style: TextStyle(
                        color: PaletaAves.morado,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          final detalles = Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ave.nombre,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: marca.tituloCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ave.nombreCientifico,
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: marca.textoCientifico,
                  ),
                ),
                const SizedBox(height: 10),
                TextoExpandible(
                  texto: ave.descripcion,
                  estilo: TextStyle(color: marca.textoCuerpo, height: 1.45),
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
                        icon: AnimatedSwitcher(
                          duration: duracion(context, 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (hijo, anim) => RotationTransition(
                            turns: Tween<double>(
                              begin: 0.035,
                              end: 0,
                            ).animate(anim),
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.65,
                                end: 1,
                              ).animate(anim),
                              child: FadeTransition(opacity: anim, child: hijo),
                            ),
                          ),
                          child: guardando
                              ? const SizedBox(
                                  key: ValueKey<String>('guardando'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  guardada
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  key: ValueKey<bool>(guardada),
                                ),
                        ),
                        label: AnimatedSwitcher(
                          duration: duracion(context, 180),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (hijo, anim) =>
                              FadeTransition(opacity: anim, child: hijo),
                          child: Text(
                            guardada ? 'Quitar' : 'Guardar',
                            key: ValueKey<bool>(guardada),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onAbrirFicha,
                        style: TextButton.styleFrom(
                          foregroundColor: PaletaAves.morado,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Aves de Chile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (esApaisada) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imagen,
                Expanded(child: detalles),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [imagen, detalles],
          );
        },
      ),
    );
  }
}

class _TarjetaAvistamientoReciente extends StatelessWidget {
  const _TarjetaAvistamientoReciente({
    required this.avistamiento,
    required this.fechaFormateada,
    required this.onAbrir,
  });

  final _AvistamientoPropio avistamiento;
  final String fechaFormateada;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: _formaTarjetaAve(context),
        child: InkWell(
          onTap: onAbrir,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(avistamiento.rutaImagen),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: marca.placeholder,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: PaletaAves.violeta,
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avistamiento.nombreAve,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 13,
                          color: PaletaAves.amarillo,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${avistamiento.lugar} · $fechaFormateada',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaFotoComunidad extends StatelessWidget {
  const _TarjetaFotoComunidad({
    required this.foto,
    required this.onAbrir,
  });

  final FotoPublica foto;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final marca = context.marca;
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: _formaTarjetaAve(context),
        child: InkWell(
          onTap: onAbrir,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                foto.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: marca.placeholder,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: PaletaAves.violeta,
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foto.autor ?? 'Observador',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          size: 13,
                          color: PaletaAves.amarillo,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            [
                              if (foto.categoria.isNotEmpty) foto.categoria,
                              if (foto.lugar != null && foto.lugar!.isNotEmpty)
                                foto.lugar!,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ShapeBorder _formaTarjetaAve(BuildContext context) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return RoundedRectangleBorder(
    side: BorderSide(
      color: esOscuro
          ? const Color(0xFFC69BFF).withValues(alpha: 0.62)
          : PaletaAves.violeta.withValues(alpha: 0.5),
      width: 1.2,
    ),
    borderRadius: BorderRadius.circular(24),
  );
}
