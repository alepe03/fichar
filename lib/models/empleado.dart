class Empleado {
  final String usuario;
  final String cifEmpresa;
  final int? id;            // Nuevo
  final String? pinFichaje; // Nuevo
  final String? direccion;
  final String? poblacion;
  final String? codigoPostal;
  final String? telefono;
  final String? email;
  final String? nombre;
  final String? dni;
  final String? rol;
  final String? passwordHash;
  final int puedeLocalizar;
  final int activo;

  Empleado({
    required this.usuario,
    required this.cifEmpresa,
    this.id,
    this.pinFichaje,
    this.direccion,
    this.poblacion,
    this.codigoPostal,
    this.telefono,
    this.email,
    this.nombre,
    this.dni,
    this.rol,
    this.passwordHash,
    this.puedeLocalizar = 0,
    this.activo = 1,
  });

  /// Crea un Empleado a partir de una línea CSV separada por ';'
  factory Empleado.fromCsv(String line) {
    final parts = line.split(';');
    return Empleado(
      usuario: parts.length > 0 ? parts[0] : '',
      cifEmpresa: parts.length > 1 ? parts[1] : '',
      id: parts.length > 2 && parts[2].isNotEmpty ? int.tryParse(parts[2]) : null,
      pinFichaje: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      direccion: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      poblacion: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      codigoPostal: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
      telefono: parts.length > 7 && parts[7].isNotEmpty ? parts[7] : null,
      email: parts.length > 8 && parts[8].isNotEmpty ? parts[8] : null,
      nombre: parts.length > 9 && parts[9].isNotEmpty ? parts[9] : null,
      dni: parts.length > 10 && parts[10].isNotEmpty ? parts[10] : null,
      rol: parts.length > 11 && parts[11].isNotEmpty ? parts[11] : null,
      passwordHash: parts.length > 12 && parts[12].isNotEmpty ? parts[12] : null,
      puedeLocalizar: parts.length > 13 && parts[13].isNotEmpty ? int.tryParse(parts[13]) ?? 0 : 0,
      activo: parts.length > 14 && parts[14].isNotEmpty ? int.tryParse(parts[14]) ?? 1 : 1,
    );
  }

  /// Crea un Empleado a partir de un Map (por ejemplo, de la base de datos)
  factory Empleado.fromMap(Map<String, Object?> map) {
    return Empleado(
      usuario: map['usuario']?.toString() ?? '',
      cifEmpresa: map['cif_empresa']?.toString() ?? '',
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      pinFichaje: map['pin_fichaje']?.toString(),
      direccion: map['direccion']?.toString(),
      poblacion: map['poblacion']?.toString(),
      codigoPostal: map['codigo_postal']?.toString(),
      telefono: map['telefono']?.toString(),
      email: map['email']?.toString(),
      nombre: map['nombre']?.toString(),
      dni: map['dni']?.toString(),
      rol: map['rol']?.toString(),
      passwordHash: map['password_hash']?.toString(),
      puedeLocalizar: map['puede_localizar'] != null ? int.tryParse(map['puede_localizar'].toString()) ?? 0 : 0,
      activo: map['activo'] != null ? int.tryParse(map['activo'].toString()) ?? 1 : 1,
    );
  }

  /// Convierte el objeto Empleado a un Map para guardar en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'usuario': usuario,
      'cif_empresa': cifEmpresa,
      'id': id,
      'pin_fichaje': pinFichaje,
      'direccion': direccion,
      'poblacion': poblacion,
      'codigo_postal': codigoPostal,
      'telefono': telefono,
      'email': email,
      'nombre': nombre,
      'dni': dni,
      'rol': rol,
      'password_hash': passwordHash,
      'puede_localizar': puedeLocalizar,
      'activo': activo,
    };
  }

  Empleado copyWith({
    String? usuario,
    String? cifEmpresa,
    int? id,
    String? pinFichaje,
    String? direccion,
    String? poblacion,
    String? codigoPostal,
    String? telefono,
    String? email,
    String? nombre,
    String? dni,
    String? rol,
    String? passwordHash,
    int? puedeLocalizar,
    int? activo,
  }) {
    return Empleado(
      usuario: usuario ?? this.usuario,
      cifEmpresa: cifEmpresa ?? this.cifEmpresa,
      id: id ?? this.id,
      pinFichaje: pinFichaje ?? this.pinFichaje,
      direccion: direccion ?? this.direccion,
      poblacion: poblacion ?? this.poblacion,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      dni: dni ?? this.dni,
      rol: rol ?? this.rol,
      passwordHash: passwordHash ?? this.passwordHash,
      puedeLocalizar: puedeLocalizar ?? this.puedeLocalizar,
      activo: activo ?? this.activo,
    );
  }
}
