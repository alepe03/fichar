// Modelo de datos para un fichaje/histórico (totalmente compatible con la API y SQLite)
// Senior style: string para códigos, máxima interoperabilidad y documentación clara

class Historico {
  final int id;                    // ID en la base de datos local
  final String uuid;               // UUID único global (sin duplicados)
  final String? cifEmpresa;        // CIF de la empresa
  final String? usuario;           // Usuario que ficha
  final String fechaEntrada;       // Fecha/hora de entrada (siempre tiene valor)
  final String? fechaSalida;       // Fecha/hora de salida (opcional)
  final String? tipo;              // Tipo de fichaje (Entrada, Salida, Incidencia)
  final String? incidenciaCodigo;  // Código de incidencia (String, tipo "IN001" o "RETARDO")
  final String? observaciones;     // Observaciones (opcional)
  final String? nombreEmpleado;    // Nombre del empleado (opcional)
  final String? dniEmpleado;       // DNI del empleado (opcional)
  final String? idSucursal;        // ID de la sucursal (opcional)
  final bool sincronizado;         // Indica si se envió a la nube
  final double? latitud;           // Latitud del fichaje (opcional)
  final double? longitud;          // Longitud del fichaje (opcional)

  // Constructor principal
  Historico({
    required this.id,
    required this.uuid,
    required this.fechaEntrada,
    this.cifEmpresa,
    this.usuario,
    this.fechaSalida,
    this.tipo,
    this.incidenciaCodigo,
    this.observaciones,
    this.nombreEmpleado,
    this.dniEmpleado,
    this.idSucursal,
    this.sincronizado = false,
    this.latitud,
    this.longitud,
  });

  /// Constructor desde Map (SQLite/local DB)
  factory Historico.fromMap(Map<String, Object?> map) {
    return Historico(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      uuid: map['uuid']?.toString() ?? '', // UUID global (¡siempre presente!)
      cifEmpresa: map['cif_empresa']?.toString().isNotEmpty == true ? map['cif_empresa']?.toString() : null,
      usuario: map['usuario']?.toString().isNotEmpty == true ? map['usuario']?.toString() : null,
      fechaEntrada: map['fecha_entrada']?.toString() ?? '',
      fechaSalida: map['fecha_salida']?.toString().isNotEmpty == true ? map['fecha_salida']?.toString() : null,
      tipo: map['tipo']?.toString().isNotEmpty == true ? map['tipo']?.toString() : null,
      incidenciaCodigo: map['incidencia_codigo']?.toString().isNotEmpty == true
          ? map['incidencia_codigo']?.toString()
          : null,
      observaciones: map['observaciones']?.toString().isNotEmpty == true ? map['observaciones']?.toString() : null,
      nombreEmpleado: map['nombre_empleado']?.toString().isNotEmpty == true ? map['nombre_empleado']?.toString() : null,
      dniEmpleado: map['dni_empleado']?.toString().isNotEmpty == true ? map['dni_empleado']?.toString() : null,
      idSucursal: map['id_sucursal']?.toString().isNotEmpty == true ? map['id_sucursal']?.toString() : null,
      sincronizado: map['sincronizado'] == 1,
      latitud: map['latitud'] != null ? double.tryParse(map['latitud'].toString()) : null,
      longitud: map['longitud'] != null ? double.tryParse(map['longitud'].toString()) : null,
    );
  }

  /// Constructor desde CSV (por si lo usas para importación)
  factory Historico.fromCsv(String line) {
    final parts = line.split(';');
    return Historico(
      id: parts.length > 0 && parts[0].isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      cifEmpresa: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      usuario: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      fechaEntrada: parts.length > 3 ? parts[3] : '',
      fechaSalida: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      tipo: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      incidenciaCodigo: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
      observaciones: parts.length > 7 && parts[7].isNotEmpty ? parts[7] : null,
      nombreEmpleado: parts.length > 8 && parts[8].isNotEmpty ? parts[8] : null,
      dniEmpleado: parts.length > 9 && parts[9].isNotEmpty ? parts[9] : null,
      idSucursal: parts.length > 10 && parts[10].isNotEmpty ? parts[10] : null,
      latitud: parts.length > 11 && parts[11].isNotEmpty ? double.tryParse(parts[11]) : null,
      longitud: parts.length > 12 && parts[12].isNotEmpty ? double.tryParse(parts[12]) : null,
      uuid: parts.length > 13 && parts[13].isNotEmpty ? parts[13] : '', // <--- UUID desde CSV
      sincronizado: true,
    );
  }

  /// Para visualización/sincronización (incluye todos los campos)
  Map<String, dynamic> toMap() {
    return {
      'id'               : id,
      'uuid'             : uuid,
      'cif_empresa'      : cifEmpresa,
      'usuario'          : usuario,
      'fecha_entrada'    : fechaEntrada,
      'fecha_salida'     : fechaSalida,
      'tipo'             : tipo,
      'incidencia_codigo': incidenciaCodigo,
      'observaciones'    : observaciones,
      'nombre_empleado'  : nombreEmpleado,
      'dni_empleado'     : dniEmpleado,
      'id_sucursal'      : idSucursal,
      'sincronizado'     : sincronizado ? 1 : 0,
      'latitud'          : latitud,
      'longitud'         : longitud,
    };
  }

  /// Para guardar en SQLite (sin id, para inserciones)
  Map<String, dynamic> toDbMap() {
    return {
      'uuid'             : uuid,
      'cif_empresa'      : cifEmpresa,
      'usuario'          : usuario,
      'fecha_entrada'    : fechaEntrada,
      'fecha_salida'     : fechaSalida,
      'tipo'             : tipo,
      'incidencia_codigo': incidenciaCodigo,
      'observaciones'    : observaciones,
      'nombre_empleado'  : nombreEmpleado,
      'dni_empleado'     : dniEmpleado,
      'id_sucursal'      : idSucursal,
      'sincronizado'     : sincronizado ? 1 : 0,
      'latitud'          : latitud,
      'longitud'         : longitud,
    };
  }
}

/// Extensión: Para enviar a PHP solo los campos requeridos.
extension HistoricoPhp on Historico {
  /// Convierte el fichaje a un mapa solo con los campos necesarios para la API PHP
  Map<String, String> toPhpBody() {
    final map = {
      'uuid'             : uuid, // UUID siempre se envía
      'cif_empresa'      : cifEmpresa      ?? '',
      'usuario'          : usuario         ?? '',
      'fecha_entrada'    : fechaEntrada,   // SIEMPRE TIENE VALOR
      'tipo'             : tipo            ?? '',
      'observaciones'    : observaciones   ?? '',
      'nombre_empleado'  : nombreEmpleado  ?? '',
      'dni_empleado'     : dniEmpleado     ?? '',
      'id_sucursal'      : idSucursal      ?? '',
    };
    // Solo enviamos fecha_salida si tiene valor
    if (fechaSalida != null && fechaSalida!.isNotEmpty) {
      map['fecha_salida'] = fechaSalida!;
    }
    // Si el fichaje es de tipo incidencia, enviamos el código de incidencia
    if (tipo != null && tipo!.toLowerCase().contains('incidencia') && incidenciaCodigo != null && incidenciaCodigo!.isNotEmpty) {
      map['incidencia_codigo'] = incidenciaCodigo!;
    }
    // Enviamos latitud y longitud si existen
    if (latitud != null) {
      map['latitud'] = latitud.toString();
    }
    if (longitud != null) {
      map['longitud'] = longitud.toString();
    }
    return map;
  }
}
