/// Modelo de datos para un empleado de la empresa.
/// Representa la información básica y de control de acceso de cada empleado.
class Empleado {
  final String usuario;         // Identificador único del usuario (login)
  final String cifEmpresa;      // CIF de la empresa a la que pertenece
  final String? direccion;      // Dirección del empleado (opcional)
  final String? poblacion;      // Población/ciudad (opcional)
  final String? codigoPostal;   // Código postal (opcional)
  final String? telefono;       // Teléfono de contacto (opcional)
  final String? email;          // Email del empleado (opcional)
  final String? nombre;         // Nombre completo (opcional)
  final String? dni;            // DNI/NIF del empleado (opcional)
  final String? rol;            // Rol o perfil (admin, user, etc.) (opcional)
  final String? passwordHash;   // Hash de la contraseña (opcional)
  final int puedeLocalizar;     // 1=puede ser localizado, 0=no (por privacidad)
  final int activo;             // 1=activo, 0=de baja

  /// Constructor principal
  Empleado({
    required this.usuario,
    required this.cifEmpresa,
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
      direccion: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      poblacion: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      codigoPostal: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      telefono: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      email: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
      nombre: parts.length > 7 && parts[7].isNotEmpty ? parts[7] : null,
      dni: parts.length > 8 && parts[8].isNotEmpty ? parts[8] : null,
      rol: parts.length > 9 && parts[9].isNotEmpty ? parts[9] : null,
      passwordHash: parts.length > 10 && parts[10].isNotEmpty ? parts[10] : null,
      puedeLocalizar: parts.length > 11 && parts[11].isNotEmpty ? int.tryParse(parts[11]) ?? 0 : 0,
      activo: parts.length > 12 && parts[12].isNotEmpty ? int.tryParse(parts[12]) ?? 1 : 1,
    );
  }

  /// Crea un Empleado a partir de un Map (por ejemplo, de la base de datos)
  factory Empleado.fromMap(Map<String, Object?> map) {
    return Empleado(
      usuario: map['usuario']?.toString() ?? '',
      cifEmpresa: map['cif_empresa']?.toString() ?? '',
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

  /// Permite crear una copia del empleado con algunos campos modificados
  Empleado copyWith({
    String? usuario,
    String? cifEmpresa,
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
