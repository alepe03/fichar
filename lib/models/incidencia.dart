// Modelo de datos para una incidencia (alineado con backend)
class Incidencia {
  final String codigo;           // Código de la incidencia (varchar en BBDD)
  final String? descripcion;     // Descripción (opcional)
  final String? cifEmpresa;      // CIF empresa (opcional)

  // Constructor
  Incidencia({
    required this.codigo,
    this.descripcion,
    this.cifEmpresa,
  });

  // Crea una incidencia a partir de un Map (SQLite/local DB)
  factory Incidencia.fromMap(Map<String, Object?> map) {
    return Incidencia(
      codigo: map['codigo']?.toString() ?? '',
      descripcion: (map['descripcion']?.toString().isNotEmpty ?? false)
          ? map['descripcion']?.toString()
          : null,
      cifEmpresa: (map['cif_empresa']?.toString().isNotEmpty ?? false)
          ? map['cif_empresa']?.toString()
          : null,
    );
  }

  // Crea una incidencia a partir de una línea CSV (de la API)
  factory Incidencia.fromCsv(String line) {
    final parts = line.split(';');
    return Incidencia(
      codigo: parts.isNotEmpty ? parts[0] : '',
      descripcion: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      cifEmpresa: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }

  // Convierte la incidencia a un mapa (para guardar en base de datos local)
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cif_empresa': cifEmpresa,
    };
  }

  @override
  String toString() => 'Incidencia($codigo, $descripcion, $cifEmpresa)';
}
