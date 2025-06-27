class Incidencia {
  final int codigo;
  final String? descripcion;
  final String? cifEmpresa;

  Incidencia({
    required this.codigo,
    this.descripcion,
    this.cifEmpresa,
  });

  // Desde SQLite o Map (asegura robustez si algún campo viene null o vacío)
  factory Incidencia.fromMap(Map<String, Object?> map) {
    return Incidencia(
      codigo: int.tryParse(map['codigo']?.toString() ?? '') ?? 0,
      descripcion: map['descripcion']?.toString().isNotEmpty == true ? map['descripcion']?.toString() : null,
      cifEmpresa: map['cif_empresa']?.toString().isNotEmpty == true ? map['cif_empresa']?.toString() : null,
    );
  }

  // Desde CSV (de la API)
  factory Incidencia.fromCsv(String line) {
    final parts = line.split(';');
    return Incidencia(
      codigo: parts.length > 0 && parts[0].isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      descripcion: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      cifEmpresa: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }

  // Para guardar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cif_empresa': cifEmpresa,
    };
  }
}
