import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ave_catalogo.dart';
import '../models/avistamiento_propio.dart';
import '../models/filtro_coleccion.dart';
import '../models/foto_guardada.dart';
import '../models/foto_publica.dart';
import '../models/reporte_foto.dart';
import '../services/auth_service.dart';
import '../services/catalogo_aves_service.dart';
import '../services/coleccion_local_service.dart';
import '../services/fotos_service.dart';
import '../services/subidas_pendientes_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogo_reporte.dart';
import '../widgets/formulario_avistamiento_dialog.dart';
import '../widgets/logo_marca.dart';
import 'catalogo_screen.dart';
import 'coleccion_screen.dart';
import 'explorar_screen.dart';
import 'inicio_screen.dart';
import 'perfil_screen.dart';

/// Contenedor principal de la app: gestiona la navegación entre secciones
/// y coordina colección, catálogo, avistamientos y reportes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onAlternarTema});

  final VoidCallback onAlternarTema;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceSeleccionado = 0;
  bool _entradaCatalogoPendiente = true;
  final PageController _controladorPaginas = PageController();
  final ImagePicker _selectorImagen = ImagePicker();
  final TextEditingController _controladorBusqueda = TextEditingController();
  final FotosService _fotosServicio = FotosService();
  final CatalogoAvesService _catalogoServicio = CatalogoAvesService();
  final ColeccionLocalService _coleccionLocalServicio = ColeccionLocalService();
  final SubidasPendientesService _subidasPendientesServicio =
      SubidasPendientesService();
  List<FotoGuardada> _fotosGuardadas = [];
  List<AvistamientoPropio> _avistamientosPropios = [];
  List<ReporteFoto> _reportesFotos = [];
  List<AveCatalogo> _avesCargadas = [];
  int _fichasCargadas = 0;
  final Set<String> _avesGuardandose = {};
  bool _cargandoColeccion = true;
  bool _guardandoAvistamiento = false;
  String? _errorColeccion;
  String _consulta = '';
  String _categoriaSeleccionada = 'Todas';
  FiltroColeccion _filtroColeccion = const FiltroColeccion();
  String? _nombreInicio;
  final List<FotoPublica> _fotosFeedInicio = [];
  bool _cargandoFeedInicio = true;
  late Future<List<AveCatalogo>> _aves;

  @override
  void initState() {
    super.initState();
    _aves = _cargarAves();
    _cargarColeccion();
    _cargarSesionInicio();
    _cargarFeedInicio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // retrieveLostData() es exclusivo de Android (fotos perdidas si el SO
      // mata la actividad). En escritorio/web/iOS lanza UnimplementedError.
      if (Platform.isAndroid) {
        _recuperarImagenPerdida();
      }
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
      final fotos = [...pagina.fotos]
        ..sort((a, b) {
          final ta =
              a.subidaEn ??
              (a.fecha != null ? DateTime.tryParse(a.fecha!) : null);
          final tb =
              b.subidaEn ??
              (b.fecha != null ? DateTime.tryParse(b.fecha!) : null);
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      setState(() {
        _fotosFeedInicio
          ..clear()
          ..addAll(fotos);
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

  Future<List<AveCatalogo>> _cargarAves() async {
    final indice = await _catalogoServicio.cargarIndice();

    final aves = indice.map((entrada) {
      return AveCatalogo(
        uid: entrada.uid,
        nombre: entrada.nombre,
        categoria: '',
        nombreCientifico: entrada.nombreCientifico,
        descripcion: '',
        palabrasClave: entrada.palabrasClave,
        urlImagen: _catalogoServicio.urlImagenAve(
          entrada.uid,
          entrada.miniatura,
        ),
        urlImagenCompleta: _catalogoServicio.urlImagenAve(
          entrada.uid,
          entrada.imagen,
        ),
        urlFicha: _catalogoServicio.urlFichaAve(entrada.uid),
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
      inicio += CatalogoAvesService.solicitudesCatalogoPorLote
    ) {
      final fin = (inicio + CatalogoAvesService.solicitudesCatalogoPorLote)
          .clamp(0, indice.length);
      final lote = indice.sublist(inicio, fin);
      final fichas = await Future.wait(lote.map(_catalogoServicio.cargarFicha));
      for (final ficha in fichas) {
        final indiceAve = aves.indexWhere((ave) => ave.uid == ficha.uid);
        if (indiceAve >= 0) aves[indiceAve] = ficha;
      }
      if (mounted) {
        setState(() {
          _avesCargadas = List<AveCatalogo>.of(aves);
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

  Future<void> _cargarColeccion() async {
    try {
      final datos = await _coleccionLocalServicio.cargar();
      if (!mounted) return;
      setState(() {
        _fotosGuardadas = datos.fotos;
        _avistamientosPropios = datos.avistamientos;
        _reportesFotos = datos.reportes;
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

  Future<void> _guardarAve(AveCatalogo ave) async {
    if (_fotosGuardadas.any((foto) => foto.id == ave.uid) ||
        _avesGuardandose.contains(ave.uid)) {
      return;
    }

    setState(() {
      _avesGuardandose.add(ave.uid);
    });

    try {
      final uriImagen = Uri.parse(ave.urlImagenCompleta);
      final rutaImagen = await _coleccionLocalServicio
          .descargarImagenAColeccion(
            uri: uriImagen,
            idOrigen: ave.uid,
            nombreArchivoFuente: uriImagen.pathSegments.last,
            mensajeNoImagenValida:
                'Aves de Chile no devolvió un archivo de imagen válido.',
          );

      final fotoGuardada = FotoGuardada(
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
      final guardado = await _coleccionLocalServicio.guardarFotos(nuevasFotos);
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

  Future<bool> _quitarAvistamiento(AvistamientoPropio avistamiento) async {
    var registroQuitado = false;
    try {
      final nuevosAvistamientos = _avistamientosPropios
          .where((item) => item.rutaImagen != avistamiento.rutaImagen)
          .toList();
      final guardado = await _coleccionLocalServicio.guardarAvistamientos(
        nuevosAvistamientos,
      );
      if (!guardado) {
        throw StateError('No se pudo actualizar la bitácora.');
      }
      registroQuitado = true;

      await _coleccionLocalServicio.borrarArchivo(avistamiento.rutaImagen);
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

  Future<bool> _quitarDeColeccion(FotoGuardada foto) async {
    var registroQuitado = false;
    try {
      final nuevasFotos = _fotosGuardadas
          .where((guardada) => guardada.id != foto.id)
          .toList();
      final guardado = await _coleccionLocalServicio.guardarFotos(nuevasFotos);
      if (!guardado) {
        throw StateError('No se pudo actualizar la colección.');
      }
      registroQuitado = true;

      await _coleccionLocalServicio.borrarArchivo(foto.rutaImagen);
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

  void _quitarAveCatalogo(AveCatalogo ave) {
    final fotosGuardadas = _fotosGuardadas.where((foto) => foto.id == ave.uid);
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
  }

  void _alQuitarAvistamiento(AvistamientoPropio avistamiento) {
    if (!mounted) return;
    setState(() {
      _avistamientosPropios = _avistamientosPropios
          .where((item) => item.rutaImagen != avistamiento.rutaImagen)
          .toList();
    });
  }

  void _alQuitarFoto(FotoGuardada foto) {
    if (!mounted) return;
    setState(() {
      _fotosGuardadas = _fotosGuardadas
          .where((guardada) => guardada.id != foto.id)
          .toList();
    });
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
    } on UnimplementedError {
      // Plataforma sin soporte de "datos perdidos": no hay nada que recuperar.
    }
  }

  Future<void> _procesarImagenSeleccionada(XFile imagen) async {
    final datosAvistamiento = await _solicitarDatosAvistamiento();
    if (!mounted || datosAvistamiento == null) return;
    await _guardarAvistamiento(imagen, datosAvistamiento);
  }

  Future<DatosAvistamiento?> _solicitarDatosAvistamiento() async {
    return showDialog<DatosAvistamiento>(
      context: context,
      builder: (_) =>
          FormularioAvistamientoDialog(formatearFecha: formatearFecha),
    );
  }

  Future<void> _guardarAvistamiento(
    XFile imagen,
    DatosAvistamiento datos,
  ) async {
    if (!mounted || _guardandoAvistamiento) return;
    setState(() {
      _guardandoAvistamiento = true;
    });

    String? rutaImagen;
    try {
      final rutaCopiada = await _coleccionLocalServicio
          .copiarImagenAvistamiento(
            rutaOrigen: imagen.path,
            nombreOrigen: imagen.name,
          );
      rutaImagen = rutaCopiada;

      final avistamiento = AvistamientoPropio(
        nombreAve: datos.nombreAve,
        nombreCientifico: datos.nombreCientifico,
        categoria: datos.categoria,
        lugar: datos.lugar,
        fecha: datos.fecha,
        comentario: datos.comentario,
        rutaImagen: rutaImagen,
      );
      final nuevosAvistamientos = [avistamiento, ..._avistamientosPropios];
      final guardado = await _coleccionLocalServicio.guardarAvistamientos(
        nuevosAvistamientos,
      );
      if (!guardado) {
        throw StateError('No se pudieron guardar los datos del avistamiento.');
      }

      if (!mounted) return;
      setState(() {
        _avistamientosPropios = nuevosAvistamientos;
      });
      _mostrarMensaje('La foto y los datos se guardaron en tu bitácora.');
      unawaited(_subirAvistamientoAlBff(rutaImagen: rutaImagen, datos: datos));
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
        for (final rutaTemporal in [rutaImagen, '$rutaImagen.tmp']) {
          try {
            await _coleccionLocalServicio.borrarArchivo(rutaTemporal);
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
    required DatosAvistamiento datos,
  }) async {
    final pendiente = <String, String>{
      'rutaImagen': rutaImagen,
      'categoria': _categoriaBff(datos.categoria),
      'lugar': datos.lugar,
      'fecha': datos.fecha.toIso8601String().split('T').first,
      'comentario': datos.comentario,
      'nombreAve': datos.nombreAve,
    };

    final resultado = await _subidasPendientesServicio.subirOEncolar(pendiente);
    if (resultado == ResultadoSubidaAvistamiento.encolada && mounted) {
      _mostrarMensaje(
        'Sin conexión con el servidor: la foto se subirá cuando vuelva la conexión.',
      );
    }
  }

  Future<void> _reintentarSubidasPendientes() async {
    final resultado = await _subidasPendientesServicio.reintentarPendientes();
    if (resultado == ResultadoReintentosSubida.todasSubidas && mounted) {
      _mostrarMensaje('Se subieron las fotos que estaban pendientes.');
    }
  }

  Future<void> _reportarFoto({
    required String nombre,
    required String referenciaImagen,
    required String origen,
    String? idFotoRemota,
  }) async {
    final datos = await solicitarMotivosReporte(context);
    if (!mounted || datos == null) return;

    final nuevoReporte = ReporteFoto(
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
      final guardado = await _coleccionLocalServicio.guardarReportes(
        nuevosReportes,
      );
      if (!guardado) {
        throw StateError('El dispositivo no pudo guardar el reporte.');
      }
      if (!mounted) return;

      setState(() {
        _reportesFotos = nuevosReportes;
      });
      _mostrarMensaje(
        enviadoAlServidor ? 'Reporte enviado a moderación.' : 'Reporte guardado en este dispositivo. Se enviará cuando haya conexión con el servidor.',
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

  Future<void> _abrirFicha(AveCatalogo ave) async {
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

  void _reintentarCargarColeccion() {
    setState(() {
      _cargandoColeccion = true;
      _errorColeccion = null;
    });
    _cargarColeccion();
  }

  void _reportarAveCatalogo(AveCatalogo ave) {
    _reportarFoto(
      nombre: ave.nombre,
      referenciaImagen: ave.urlImagen,
      origen: 'Aves de Chile',
    );
  }

  void _reportarAvistamiento(AvistamientoPropio avistamiento) {
    _reportarFoto(
      nombre: avistamiento.nombreAve,
      referenciaImagen: avistamiento.rutaImagen,
      origen: 'Avistamiento propio',
    );
  }

  void _reportarFotoGuardada(FotoGuardada foto) {
    _reportarFoto(
      nombre: foto.nombre,
      referenciaImagen: foto.urlImagen,
      origen: 'Aves de Chile guardada',
    );
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
            const LogoMarca(tamano: 38),
            const SizedBox(width: 10),
            const Text(
              'CORON',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
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
                child: FloatingActionButton(
                  onPressed: _mostrarOpcionesImagen,
                  tooltip: 'Agregar foto',
                  backgroundColor: PaletaAves.amarillo,
                  foregroundColor: PaletaAves.morado,
                  elevation: 6,
                  child: const Icon(Icons.add_a_photo_outlined),
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

  Widget _construirInicio() {
    return InicioScreen(
      nombreUsuario: _nombreInicio,
      avistamientos: _avistamientosPropios,
      fotosGuardadas: _fotosGuardadas,
      fotosComunidad: _fotosFeedInicio,
      cargandoComunidad: _cargandoFeedInicio,
      onAgregarFoto: _mostrarOpcionesImagen,
      onVerColeccion: () => _alTocarItem(3),
      onVerExplorar: () => _alTocarItem(2),
      onVerCatalogo: () => _alTocarItem(1),
    );
  }

  Widget _construirBusqueda() {
    return CatalogoScreen(
      aves: _aves,
      avesCargadas: _avesCargadas,
      fichasCargadas: _fichasCargadas,
      entradaCatalogoPendiente: _entradaCatalogoPendiente,
      consulta: _consulta,
      categoriaSeleccionada: _categoriaSeleccionada,
      controladorBusqueda: _controladorBusqueda,
      fotosGuardadas: _fotosGuardadas,
      avesGuardandose: _avesGuardandose,
      onConsultaChanged: (valor) => setState(() => _consulta = valor),
      onCategoriaChanged: (valor) {
        setState(() {
          _categoriaSeleccionada = valor;
        });
      },
      onReintentar: () {
        setState(() {
          _aves = _cargarAves();
          _entradaCatalogoPendiente = true;
        });
      },
      onReintentarCarga: () {
        setState(() {
          _avesCargadas = [];
          _fichasCargadas = 0;
          _aves = _cargarAves();
          _entradaCatalogoPendiente = true;
        });
      },
      onAbrirFicha: _abrirFicha,
      onReportar: _reportarAveCatalogo,
      onGuardar: _guardarAve,
      onQuitar: _quitarAveCatalogo,
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
      final rutaImagen = await _coleccionLocalServicio
          .descargarImagenAColeccion(
            uri: uriImagen,
            idOrigen: foto.id,
            nombreArchivoFuente: uriImagen.pathSegments.isEmpty
                ? 'foto.jpg'
                : uriImagen.pathSegments.last,
            mensajeNoImagenValida:
                'El servidor no devolvió un archivo de imagen válido.',
          );

      final fotoGuardada = FotoGuardada(
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
      final guardado = await _coleccionLocalServicio.guardarFotos(nuevasFotos);
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

  Widget _construirColeccion() {
    return ColeccionScreen(
      cargando: _cargandoColeccion,
      error: _errorColeccion,
      fotosGuardadas: _fotosGuardadas,
      avistamientosPropios: _avistamientosPropios,
      avesCargadas: _avesCargadas,
      filtro: _filtroColeccion,
      onReintentarCarga: _reintentarCargarColeccion,
      onFiltroChanged: (filtro) {
        setState(() {
          _filtroColeccion = filtro;
        });
      },
      onQuitarAvistamiento: _quitarAvistamiento,
      onAvistamientoQuitado: _alQuitarAvistamiento,
      onQuitarFoto: _quitarDeColeccion,
      onFotoQuitada: _alQuitarFoto,
      onReportarAvistamiento: _reportarAvistamiento,
      onReportarFoto: _reportarFotoGuardada,
      onAbrirFicha: (url) => _abrirEnlaceFuente(url),
    );
  }

  Widget _construirPerfil() {
    return PerfilScreen(reportesGuardados: _reportesFotos.length);
  }
}
