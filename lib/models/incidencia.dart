class Incidencia {
  final String codigo;
  final String? descripcion;
  final String? cifEmpresa;

  final bool computa; // NUEVO CAMPO

  Incidencia({
    required this.codigo,
    this.descripcion,
    this.cifEmpresa,
    this.computa = true, // valor por defecto
  });

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

  factory Incidencia.fromCsv(String line) {
    final parts = line.split(';');
    return Incidencia(
      codigo: parts.isNotEmpty ? parts[0] : '',
      descripcion: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      cifEmpresa: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      computa: parts.length > 3 ? parts[3] == '1' : true, // si CSV incluye computa
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'cif_empresa': cifEmpresa,
      'computa': computa ? 1 : 0, // guardar como int
    };
  }

  @override
  String toString() => 'Incidencia($codigo, $descripcion, $cifEmpresa, computa=$computa)';
}
