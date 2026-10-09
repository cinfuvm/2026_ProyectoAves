import 'package:bitacora_aves/models/categoria_ave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agrupa los órdenes conocidos en categorías generales', () {
    const ordenesPorCategoria = {
      'Rapaces': [
        'Accipitriformes',
        'Cathartiformes',
        'Falconiformes',
        'Strigiformes',
      ],
      'Marinas': ['Procellariiformes', 'Sphenisciformes', 'Suliformes'],
      'Acuáticas': [
        'Anseriformes',
        'Charadriiformes',
        'Coraciiformes',
        'Gruiformes',
        'Pelecaniformes',
        'Phoenicopteriformes',
        'Podicipediformes',
      ],
      'Terrestres': [
        'Apodiformes',
        'Caprimulgiformes',
        'Columbiformes',
        'Galliformes',
        'Passeriformes - Suborden Passeres',
        'Passeriformes - Suborden Tyranni',
        'Piciformes',
        'Psittaciformes',
        'Rheiformes',
        'Tinamiformes',
      ],
    };

    for (final grupo in ordenesPorCategoria.entries) {
      for (final orden in grupo.value) {
        expect(categoriaGeneralAves(orden), grupo.key);
      }
    }
  });

  test('normaliza categorías anteriores y conserva sin categoría', () {
    expect(categoriaGeneralAves('Bosque'), 'Terrestres');
    expect(categoriaGeneralAves('Humedal'), 'Acuáticas');
    expect(categoriaGeneralAves('Picaflores'), 'Terrestres');
    expect(categoriaGeneralAves('Rapaces'), 'Rapaces');
    expect(categoriaGeneralAves(''), isEmpty);
    expect(categoriaGeneralAves('Orden desconocido'), 'Otras');
  });
}
