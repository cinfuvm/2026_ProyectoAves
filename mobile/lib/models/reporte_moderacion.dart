/// Fotografía sobre la que se abrió un reporte, con los datos que la pantalla
/// de moderación pinta al lado del motivo.
class FotoReportada {
  const FotoReportada({
    required this.id,
    required this.url,
    this.categoria = '',
    this.autor,
    this.lugar,
    this.comentario,
  });

  factory FotoReportada.fromJson(Map<String, dynamic> json) => FotoReportada(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    categoria: json['categoria'] as String? ?? '',
    autor: json['autor'] as String?,
    lugar: json['lugar'] as String?,
    comentario: json['comentario'] as String?,
  );

  final String id;
  final String url;
  final String categoria;
  final String? autor;
  final String? lugar;
  final String? comentario;
}

/// Reporte de moderación tal y como lo devuelve `GET /images/reports`.
///
/// No es el mismo objeto que `ReporteFoto`, que es el que la app guarda en el
/// dispositivo al reportar una foto: este es el que ya está en la base de datos
/// y solo lo puede leer el rol `admin`.
class ReporteModeracion {
  const ReporteModeracion({
    required this.id,
    required this.motivo,
    required this.estado,
    this.detalle = '',
    this.creadoEn,
    this.reportadoPor,
    this.avistamiento,
  });

  factory ReporteModeracion.fromJson(Map<String, dynamic> json) {
    final avistamiento = json['avistamiento'];
    final creadoEn = json['creado_en'];
    return ReporteModeracion(
      id: json['id'] as String? ?? '',
      motivo: json['motivo'] as String? ?? '',
      estado: json['estado'] as String? ?? 'abierto',
      detalle: json['detalle'] as String? ?? '',
      creadoEn: creadoEn is String ? DateTime.tryParse(creadoEn) : null,
      reportadoPor: json['reportado_por'] as String?,
      avistamiento: avistamiento is Map<String, dynamic>
          ? FotoReportada.fromJson(avistamiento)
          : null,
    );
  }

  final String id;

  /// Código del contrato: `no_es_ave`, `contenido_ofensivo`, `imagen_enganosa`,
  /// `derechos_autor` u `otro`. El texto legible lo resuelve la pantalla con
  /// `motivosReporteContrato`.
  final String motivo;

  /// `abierto`, `revisado` o `descartado`.
  final String estado;

  /// Texto libre que escribió quien lo abrió. Puede venir vacío.
  final String detalle;
  final DateTime? creadoEn;

  /// Usuario que abrió el reporte; `null` si ya no existe la cuenta.
  final String? reportadoPor;

  /// `null` si la foto se borró después de haber sido reportada: el reporte
  /// se conserva igual, pero no hay con qué juzgarlo.
  final FotoReportada? avistamiento;

  bool get abierto => estado == 'abierto';

  ReporteModeracion copiarCon({String? estado}) => ReporteModeracion(
    id: id,
    motivo: motivo,
    estado: estado ?? this.estado,
    detalle: detalle,
    creadoEn: creadoEn,
    reportadoPor: reportadoPor,
    avistamiento: avistamiento,
  );
}
