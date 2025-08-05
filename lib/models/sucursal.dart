// Modelo de datos para una sucursal
class Sucursal {
  final String cifEmpresa;   // CIF de la empresa (obligatorio)
  final String codigo;       // Código de la sucursal (obligatorio)
  final String nombre;       // Nombre de la sucursal (obligatorio)
  final String? direccion;   // Dirección de la sucursal (opcional)
  final String? horario;     // Horario de la sucursal (opcional)

  // Constructor principal para crear una sucursal
  Sucursal({
    required this.cifEmpresa,
    required this.codigo,
    required this.nombre,
    this.direccion,
    this.horario,
  });

  // Crea una sucursal a partir de un Map (por ejemplo, desde SQLite/local DB)
  factory Sucursal.fromMap(Map<String, dynamic> map) {
    return Sucursal(
      cifEmpresa: map['cif_empresa']?.toString() ?? '',
      codigo: map['codigo']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      direccion: (map['direccion']?.toString().isNotEmpty ?? false) ? map['direccion'] as String : null,
      horario: (map['horario']?.toString().isNotEmpty ?? false) ? map['horario'] as String : null,
    );
  }

  // Crea una sucursal a partir de una línea CSV (de la API)
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

  // Convierte la sucursal a un mapa (para guardar en base de datos)
  Map<String, dynamic> toMap() {
    return {
      'cif_empresa': cifEmpresa, // CIF de la empresa
      'codigo': codigo,          // Código de la sucursal
      'nombre': nombre,          // Nombre de la sucursal
      'direccion': direccion,    // Dirección (opcional)
      'horario': horario,        // Horario (opcional)
    };
  }
}
