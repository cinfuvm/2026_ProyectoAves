import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TextoExpandible extends StatefulWidget {
  const TextoExpandible({
    super.key,
    required this.texto,
    this.estilo,
    this.maxLineas = 3,
  });

  final String texto;
  final TextStyle? estilo;
  final int maxLineas;

  @override
  State<TextoExpandible> createState() => _TextoExpandibleState();
}

class _TextoExpandibleState extends State<TextoExpandible> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style.merge(widget.estilo);

    return LayoutBuilder(
      builder: (context, constraints) {
        final medidor = TextPainter(
          text: TextSpan(text: widget.texto, style: estilo),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: widget.maxLineas,
        )..layout(maxWidth: constraints.maxWidth);
        final necesitaExpandir = medidor.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              alignment: Alignment.topLeft,
              duration: duracion(context, 180),
              curve: Curves.easeInOutCubic,
              child: Text(
                widget.texto,
                maxLines: _expandido ? null : widget.maxLineas,
                overflow: _expandido
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: estilo,
              ),
            ),
            if (necesitaExpandir)
              TextButton.icon(
                onPressed: () => setState(() => _expandido = !_expandido),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                label: Text(_expandido ? 'Ver menos' : 'Ver más'),
              ),
          ],
        );
      },
    );
  }
}
