import 'package:flutter/material.dart';

import '../models/reporte_foto.dart';

const _motivosReporte = [
  'La foto no muestra un ave',
  'Contenido inapropiado',
  'La imagen o información es engañosa',
  'Imagen duplicada o de baja calidad',
  'Otro motivo',
];

/// Muestra el diálogo de reporte de imagen y devuelve los datos elegidos,
/// o `null` si el usuario cancela.
Future<DatosReporte?> solicitarMotivosReporte(BuildContext context) async {
  final motivosSeleccionados = <String>{};
  final otroMotivoController = TextEditingController();

  try {
    return await showDialog<DatosReporte>(
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
                        DatosReporte(
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
