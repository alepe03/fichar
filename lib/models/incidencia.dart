// Modelo de datos para una incidencia (motivo de fichaje especial, ausencia, etc.)

class Incidencia {
  final String codigo;           // Código único de la incidencia (ej: "IN001")
  final String? descripcion;     // Descripción de la incidencia (opcional)
  final String? cifEmpresa;      // CIF de la empresa asociada (opcional)

  final bool computa; // Indica si la incidencia computa como jornada (true=cuenta, false=no)

  /// Constructor principal
  Incidencia({
    required this.codigo,
    this.descripcion,
    this.cifEmpresa,
    this.computa = true, // valor por defecto: computa
  });

  /// Crea una Incidencia a partir de un Map (por ejemplo, desde SQLite o una API)
  factory Incidencia.fromMap(Map<String, Object?> map) {
    return Incidencia(
      codigo: map['codigo']?.toString() ?? '',
      descripcion: (map['descripcion']?.toString().isNotEmpty ?? false)
          ? map['descripcion']?.toString()
          : null,
      cifEmpresa: (map['cif_empresa']?.toString().isNotEmpty ?? false)
          ? map['cif_empresa']?.toString()
          : null,
      computa: (map['computa'] ?? 1) == 1,  // Asumimos que 1 = true, 0 = false
    );
  }

  /// Crea una Incidencia a partir de una línea CSV separada por ';'
  factory Incidencia.fromCsv(String line) {
    final parts = line.split(';');
    return Incidencia(
      codigo: parts.isNotEmpty ? parts[0] : '',
      descripcion: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      cifEmpresa: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      computa: parts.length > 3 ? parts[3] == '1' : true, // si CSV incluye computa
    );
  }

  /// Convierte la incidencia a un Map para guardar en la base de datos o enviar por red
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cif_empresa': cifEmpresa,
      'computa': computa ? 1 : 0, // guardar como int (1/0)
    };
  }

  /// Representación legible del objeto (útil para debug)
  @override
  String toString() => 'Incidencia($codigo, $descripcion, $cifEmpresa, computa=$computa)';
}
