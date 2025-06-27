class Sucursal {
  final String cifEmpresa;   // NOT NULL
  final String codigo;       // NOT NULL
  final String nombre;       // NOT NULL
  final String? direccion;   // Puede ser NULL
  final String? horario;     // Puede ser NULL

  Sucursal({
    required this.cifEmpresa,
    required this.codigo,
    required this.nombre,
    this.direccion,
    this.horario,
  });

  // Desde SQLite/Map
  factory Sucursal.fromMap(Map<String, dynamic> map) {
    return Sucursal(
      cifEmpresa: map['cif_empresa']?.toString() ?? '',
      codigo: map['codigo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      direccion: (map['direccion']?.toString().isNotEmpty ?? false) ? map['direccion'] as String : null,
      horario: (map['horario']?.toString().isNotEmpty ?? false) ? map['horario'] as String : null,
    );
  }

  // Desde CSV (API)
  factory Sucursal.fromCsv(String line) {
    final parts = line.split(';');
    return Sucursal(
      cifEmpresa: parts.length > 0 ? parts[0] : '',
      codigo: parts.length > 1 ? parts[1] : '',
      nombre: parts.length > 2 ? parts[2] : '',
      direccion: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      horario: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cif_empresa': cifEmpresa,
      'codigo': codigo,
      'nombre': nombre,
      'direccion': direccion,
      'horario': horario,
    };
  }
}
