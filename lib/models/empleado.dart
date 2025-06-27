// Modelo de datos para un empleado
class Empleado {
  final String usuario;         // Nombre de usuario
  final String cifEmpresa;      // CIF de la empresa a la que pertenece
  final String? direccion;      // Dirección del empleado (opcional)
  final String? poblacion;      // Población (opcional)
  final String? codigoPostal;   // Código postal (opcional)
  final String? telefono;       // Teléfono (opcional)
  final String? email;          // Email (opcional)
  final String? nombre;         // Nombre completo (opcional)
  final String? dni;            // DNI/NIF (opcional)
  final String? rol;            // Rol del empleado (opcional)
  final String? passwordHash;   // Hash de la contraseña (opcional)

  // Constructor
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
  });

  // Crea un empleado a partir de una línea CSV (separada por ;)
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
    );
  }

  // Crea un empleado a partir de un mapa (por ejemplo, desde SQLite/local DB)
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
    );
  }

  // Convierte el empleado a un mapa (para guardar en base de datos)
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
    };
  }
}
