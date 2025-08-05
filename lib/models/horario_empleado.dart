// Modelo de datos para el horario de un empleado

class HorarioEmpleado {
  final int? id;                // ID único en la base de datos (autoincremental, opcional)
  final String dniEmpleado;     // DNI del empleado al que pertenece el horario
  final String cifEmpresa;      // CIF de la empresa
  final int diaSemana;          // Día de la semana (0 = Lunes, ..., 6 = Domingo)
  final String horaInicio;      // Hora de inicio del turno (formato 'HH:mm')
  final String horaFin;         // Hora de fin del turno (formato 'HH:mm')
  final String? nombreTurno;    // Nombre del turno (opcional, por ejemplo "Mañana")

  /// Constructor principal
  HorarioEmpleado({
    this.id,
    required this.dniEmpleado,
    required this.cifEmpresa,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.nombreTurno,
  });

  /// Crea un HorarioEmpleado a partir de un Map (por ejemplo, desde SQLite o una API)
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

  /// Crea un HorarioEmpleado a partir de una línea CSV separada por ';'
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

  /// Convierte el objeto a un Map para guardar en la base de datos o enviar por red
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

  /// Representación legible del objeto (útil para debug)
  @override
  String toString() {
    return 'HorarioEmpleado{id: $id, dni: $dniEmpleado, empresa: $cifEmpresa, '
        'dia: $diaSemana, $horaInicio-$horaFin, turno: $nombreTurno}';
  }
}
