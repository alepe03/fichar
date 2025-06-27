// Modelo de datos para una incidencia
class Incidencia {
  final int codigo;            // Código numérico de la incidencia
  final String? descripcion;   // Descripción de la incidencia (opcional)
  final String? cifEmpresa;    // CIF de la empresa (opcional)

  // Constructor
  Incidencia({
    required this.codigo,
    this.descripcion,
    this.cifEmpresa,
  });

  // Crea una incidencia a partir de un Map (por ejemplo, desde SQLite/local DB)
  factory Incidencia.fromMap(Map<String, Object?> map) {
    return Incidencia(
      codigo: int.tryParse(map['codigo']?.toString() ?? '') ?? 0,
      descripcion: map['descripcion']?.toString().isNotEmpty == true ? map['descripcion']?.toString() : null,
      cifEmpresa: map['cif_empresa']?.toString().isNotEmpty == true ? map['cif_empresa']?.toString() : null,
    );
  }

  // Crea una incidencia a partir de una línea CSV (de la API)
  factory Incidencia.fromCsv(String line) {
    final parts = line.split(';');
    return Incidencia(
      codigo: parts.length > 0 && parts[0].isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      descripcion: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      cifEmpresa: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }

  // Convierte la incidencia a un mapa (para guardar en base de datos)
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cif_empresa': cifEmpresa,
    };
  }
}
