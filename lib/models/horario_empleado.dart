class HorarioEmpleado {
  final int? id;
  final String dniEmpleado;
  final String cifEmpresa;
  final int diaSemana; // 0 = Lunes, ..., 6 = Domingo
  final String horaInicio; // Formato 'HH:mm'
  final String horaFin;    // Formato 'HH:mm'
  final String? nombreTurno; // Opcional

  HorarioEmpleado({
    this.id,
    required this.dniEmpleado,
    required this.cifEmpresa,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.nombreTurno,
  });

  // Desde un Map (SQLite/API)
  factory HorarioEmpleado.fromMap(Map<String, dynamic> map) {
    return HorarioEmpleado(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id']}'),
      dniEmpleado: map['dni_empleado'],
      cifEmpresa: map['cif_empresa'],
      diaSemana: map['dia_semana'] is int ? map['dia_semana'] : int.tryParse('${map['dia_semana']}') ?? 0,
      horaInicio: map['hora_inicio'],
      horaFin: map['hora_fin'],
      nombreTurno: map['nombre_turno'],
    );
  }

  // Desde una línea CSV
  factory HorarioEmpleado.fromCsv(String line) {
    final fields = line.split(';');
    return HorarioEmpleado(
      id: int.tryParse(fields[0]),
      dniEmpleado: fields[1],
      cifEmpresa: fields[2],
      diaSemana: int.tryParse(fields[3]) ?? 0,
      horaInicio: fields[4],
      horaFin: fields[5],
      nombreTurno: fields.length > 6 ? fields[6] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dni_empleado': dniEmpleado,
      'cif_empresa': cifEmpresa,
      'dia_semana': diaSemana,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'nombre_turno': nombreTurno,
    };
  }

  @override
  String toString() {
    return 'HorarioEmpleado{id: $id, dni: $dniEmpleado, empresa: $cifEmpresa, '
        'dia: $diaSemana, $horaInicio-$horaFin, turno: $nombreTurno}';
  }
}
