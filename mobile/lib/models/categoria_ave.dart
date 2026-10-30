const categoriasGeneralesAves = <String>[
  'Terrestres',
  'Acuáticas',
  'Rapaces',
  'Marinas',
  'Otras',
];

String categoriaGeneralAves(String categoria) {
  final valor = categoria.trim();
  if (valor.isEmpty) return '';

  if (categoriasGeneralesAves.contains(valor)) return valor;

  switch (valor) {
    case 'Bosque':
    case 'Pradera':
    case 'Picaflores':
      return 'Terrestres';
    case 'Humedal':
      return 'Acuáticas';
  }

  if (valor.startsWith('Passeriformes')) return 'Terrestres';

  return switch (valor) {
    'Accipitriformes' ||
    'Cathartiformes' ||
    'Falconiformes' ||
    'Strigiformes' => 'Rapaces',
    'Procellariiformes' || 'Sphenisciformes' || 'Suliformes' => 'Marinas',
    'Anseriformes' ||
    'Charadriiformes' ||
    'Coraciiformes' ||
    'Gruiformes' ||
    'Pelecaniformes' ||
    'Phoenicopteriformes' ||
    'Podicipediformes' => 'Acuáticas',
    'Apodiformes' ||
    'Caprimulgiformes' ||
    'Columbiformes' ||
    'Galliformes' ||
    'Piciformes' ||
    'Psittaciformes' ||
    'Rheiformes' ||
    'Tinamiformes' => 'Terrestres',
    _ => 'Otras',
  };
}
