class FotoPublica {
  const FotoPublica({
    required this.id,
    required this.url,
    this.categoria = '',
    this.autor,
    this.lugar,
    this.fecha,
    this.comentario,
    this.subidaEn,
  });

  factory FotoPublica.fromJson(Map<String, dynamic> json) {
    final subidaEn = json['subida_en'];
    return FotoPublica(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      autor: json['autor'] as String?,
      lugar: json['lugar'] as String?,
      fecha: json['fecha'] as String?,
      comentario: json['comentario'] as String?,
      subidaEn: subidaEn is String ? DateTime.tryParse(subidaEn) : null,
    );
  }

  final String id;
  final String url;
  final String categoria;
  final String? autor;
  final String? lugar;
  final String? fecha;
  final String? comentario;
  final DateTime? subidaEn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    if (categoria.isNotEmpty) 'categoria': categoria,
    if (autor != null) 'autor': autor,
    if (lugar != null) 'lugar': lugar,
    if (fecha != null) 'fecha': fecha,
    if (comentario != null) 'comentario': comentario,
    if (subidaEn != null) 'subida_en': subidaEn!.toIso8601String(),
  };
}

class PaginaFotos {
  const PaginaFotos({
    required this.fotos,
    required this.pagina,
    required this.total,
  });

  factory PaginaFotos.fromJson(Map<String, dynamic> json) {
    final urls = json['urls'];
    final fotos = <FotoPublica>[];
    if (urls is List<dynamic>) {
      for (final entrada in urls) {
        if (entrada is String) {
          fotos.add(FotoPublica(id: entrada, url: entrada));
        } else if (entrada is Map<String, dynamic>) {
          fotos.add(FotoPublica.fromJson(entrada));
        }
      }
    }

    var pagina = 0;
    var total = fotos.length;
    final paginado = json['paginado'];
    if (paginado is Map<String, dynamic>) {
      pagina = (paginado['pagina'] as num?)?.toInt() ?? 0;
      total = (paginado['total'] as num?)?.toInt() ?? fotos.length;
    } else if (paginado is String) {
      final partes = paginado.split('/');
      if (partes.length == 2) {
        pagina = int.tryParse(partes[0]) ?? 0;
        total = int.tryParse(partes[1]) ?? fotos.length;
      }
    }

    return PaginaFotos(fotos: fotos, pagina: pagina, total: total);
  }

  final List<FotoPublica> fotos;
  final int pagina;
  final int total;

  bool get hayMas => pagina + 1 < total;
}
