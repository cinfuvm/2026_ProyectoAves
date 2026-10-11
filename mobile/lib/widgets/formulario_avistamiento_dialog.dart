import 'package:flutter/material.dart';

import '../models/avistamiento_propio.dart';
import '../models/categoria_ave.dart';

/// Diálogo para capturar los datos de un avistamiento nuevo.
///
/// Devuelve los [DatosAvistamiento] ingresados o `null` si se cancela.
class FormularioAvistamientoDialog extends StatefulWidget {
  const FormularioAvistamientoDialog({super.key, required this.formatearFecha});

  final String Function(DateTime) formatearFecha;

  @override
  State<FormularioAvistamientoDialog> createState() =>
      _FormularioAvistamientoDialogState();
}

class _FormularioAvistamientoDialogState
    extends State<FormularioAvistamientoDialog> {
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
      DatosAvistamiento(
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
