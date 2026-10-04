import 'package:flutter/material.dart';

class TarjetaAvistamiento extends StatelessWidget {
  // Declaración de variables inmutables
  final String nombre;
  final String ubicacion;
  final String urlImagen;

  // Constructor que exige los parámetros
  const TarjetaAvistamiento({
    super.key,
    required this.nombre,
    required this.ubicacion,
    required this.urlImagen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            urlImagen, // Uso de la variable inyectada
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre, // Uso de la variable inyectada
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  ubicacion, // Uso de la variable inyectada
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey,
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