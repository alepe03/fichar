// lib/models/empresa.dart

/// Modelo de datos para una empresa
class Empresa {
  final String cifEmpresa;     // CIF de la empresa (obligatorio)
  final String nombre;         // Nombre de la empresa (obligatorio)
  final String? direccion;     // Dirección (opcional)
  final String? telefono;      // Teléfono (opcional)
  final String? codigoPostal;  // Código postal (opcional)
  final String? email;         // Email (opcional)
  final String? basedatos;     // Nombre de la base de datos (opcional)
  final int? maxUsuarios;      // Límite de usuarios activos (opcional)
  final double? cuota;         // NUEVO: importe de la cuota (opcional)
  final String? observaciones; // NUEVO: observaciones internas (opcional)

  /// Constructor
  Empresa({
    required this.cifEmpresa,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.codigoPostal,
    this.email,
    this.basedatos,
    this.maxUsuarios,
    this.cuota,
    this.observaciones,
  });

  // --- Helpers privados ---
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // admite coma o punto
    return double.tryParse(s.replaceAll(',', '.'));
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  /// Crea una empresa a partir de un Map<String, Object?> (p.ej. SQLite/JSON)
  factory Empresa.fromMap(Map<String, Object?> map) {
    return Empresa(
      cifEmpresa:   map['cif_empresa']?.toString() ?? '',
      nombre:       map['nombre']?.toString()      ?? '',
      direccion:    (map['direccion']?.toString().isNotEmpty == true)
                       ? map['direccion']?.toString()
                       : null,
      telefono:     (map['telefono']?.toString().isNotEmpty == true)
                       ? map['telefono']?.toString()
                       : null,
      codigoPostal: (map['codigo_postal']?.toString().isNotEmpty == true)
                       ? map['codigo_postal']?.toString()
                       : null,
      email:        (map['email']?.toString().isNotEmpty == true)
                       ? map['email']?.toString()
                       : null,
      basedatos:    (map['basedatos']?.toString().isNotEmpty == true)
                       ? map['basedatos']?.toString()
                       : null,
      maxUsuarios:  _toInt(map['max_usuarios_activos']),
      cuota:        _toDouble(map['cuota']),              // NUEVO
      observaciones:(map['observaciones']?.toString().isNotEmpty == true)
                       ? map['observaciones']?.toString()
                       : null,                             // NUEVO
    );
  }

  /// Crea una empresa a partir de una línea CSV (separada por ‘;’)
  /// Backend (GET Code=500) devuelve:
  /// 0:cif_empresa;1:nombre;2:direccion;3:telefono;4:codigo_postal;5:email;6:basedatos;7:max_usuarios_activos;8:cuota;9:observaciones;
  factory Empresa.fromCsv(String line) {
    final parts = line.split(';');
    String? _opt(int i) => (parts.length > i && parts[i].isNotEmpty) ? parts[i] : null;

    return Empresa(
      cifEmpresa:   _opt(0) ?? '',
      nombre:       _opt(1) ?? '',
      direccion:    _opt(2),
      telefono:     _opt(3),
      codigoPostal: _opt(4),
      email:        _opt(5),
      basedatos:    _opt(6),
      maxUsuarios:  _opt(7) != null ? int.tryParse(parts[7]) : null,
      cuota:        _opt(8) != null ? double.tryParse(parts[8].replaceAll(',', '.')) : null, // NUEVO
      observaciones:_opt(9), // NUEVO
    );
  }

  /// Crea una empresa a partir de un Map<String, String> usando cabecera→valor
  factory Empresa.fromCsvMap(Map<String, String> m) {
    String? _nz(String? s) => (s != null && s.isNotEmpty) ? s : null;
    return Empresa(
      cifEmpresa:   m['cif_empresa']            ?? '',
      nombre:       m['nombre']                 ?? '',
      direccion:    _nz(m['direccion']),
      telefono:     _nz(m['telefono']),
      codigoPostal: _nz(m['codigo_postal']),
      email:        _nz(m['email']),
      basedatos:    _nz(m['basedatos']),
      maxUsuarios:  int.tryParse(m['max_usuarios_activos'] ?? ''),
      cuota:        (m['cuota'] != null) ? double.tryParse(m['cuota']!.replaceAll(',', '.')) : null, // NUEVO
      observaciones:_nz(m['observaciones']), // NUEVO
    );
  }

  /// Convierte la empresa a un mapa (para SQLite o para enviar por POST)
  Map<String, dynamic> toMap() {
    return {
      'cif_empresa':           cifEmpresa,
      'nombre':                nombre,
      'direccion':             direccion,
      'telefono':              telefono,
      'codigo_postal':         codigoPostal,
      'email':                 email,
      'basedatos':             basedatos,
      'max_usuarios_activos':  maxUsuarios,
      'cuota':                 cuota,          // NUEVO
      'observaciones':         observaciones,  // NUEVO
    };
  }

  /// (Opcional) útil en UI
  Empresa copyWith({
    String? cifEmpresa,
    String? nombre,
    String? direccion,
    String? telefono,
    String? codigoPostal,
    String? email,
    String? basedatos,
    int? maxUsuarios,
    double? cuota,
    String? observaciones,
  }) {
    return Empresa(
      cifEmpresa:   cifEmpresa   ?? this.cifEmpresa,
      nombre:       nombre       ?? this.nombre,
      direccion:    direccion    ?? this.direccion,
      telefono:     telefono     ?? this.telefono,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      email:        email        ?? this.email,
      basedatos:    basedatos    ?? this.basedatos,
      maxUsuarios:  maxUsuarios  ?? this.maxUsuarios,
      cuota:        cuota        ?? this.cuota,
      observaciones:observaciones?? this.observaciones,
    );
  }
}
