// Modelo de datos para una empresa
class Empresa {
  final String cifEmpresa;       // CIF de la empresa (obligatorio)
  final String nombre;           // Nombre de la empresa (obligatorio)
  final String? direccion;       // Dirección (opcional)
  final String? telefono;        // Teléfono (opcional)
  final String? codigoPostal;    // Código postal (opcional)
  final String? email;           // Email (opcional)
  final String? basedatos;       // Nombre de la base de datos (opcional)

  // Constructor
  Empresa({
    required this.cifEmpresa,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.codigoPostal,
    this.email,
    this.basedatos,
  });

  // Crea una empresa a partir de un mapa (por ejemplo, desde SQLite/local DB)
  factory Empresa.fromMap(Map<String, Object?> map) {
    return Empresa(
      cifEmpresa: map['cif_empresa']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      direccion: map['direccion']?.toString().isNotEmpty == true ? map['direccion']?.toString() : null,
      telefono: map['telefono']?.toString().isNotEmpty == true ? map['telefono']?.toString() : null,
      codigoPostal: map['codigo_postal']?.toString().isNotEmpty == true ? map['codigo_postal']?.toString() : null,
      email: map['email']?.toString().isNotEmpty == true ? map['email']?.toString() : null,
      basedatos: map['basedatos']?.toString().isNotEmpty == true ? map['basedatos']?.toString() : null,
    );
  }

  // Crea una empresa a partir de una línea CSV (separada por ;)
  factory Empresa.fromCsv(String line) {
    final parts = line.split(';');
    return Empresa(
      cifEmpresa: parts.length > 0 && parts[0].isNotEmpty ? parts[0] : '',
      nombre: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : '',
      direccion: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      telefono: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      codigoPostal: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      email: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      basedatos: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
    );
  }

  // Convierte la empresa a un mapa (para guardar en base de datos)
  Map<String, dynamic> toMap() {
    return {
      'cif_empresa': cifEmpresa,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'codigo_postal': codigoPostal,
      'email': email,
      'basedatos': basedatos,
    };
  }
}
