class HorarioEmpleado {
  final int? id;
  final String dniEmpleado;
  final String cifEmpresa;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final String? nombreTurno;
  final int margenEntradaAntes;
  final int margenEntradaDespues; // <- NUEVO

  HorarioEmpleado({
    this.id,
    required this.dniEmpleado,
    required this.cifEmpresa,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.nombreTurno,
    this.margenEntradaAntes = 10,
    this.margenEntradaDespues = 30, // Valor por defecto a 30 min
  });

  factory HorarioEmpleado.fromMap(Map<String, dynamic> map) {
    return HorarioEmpleado(
      id: map['id'] is int ? map['id'] : int.tryParse('${map['id']}'),
      dniEmpleado: map['dni_empleado'],
      cifEmpresa: map['cif_empresa'],
      diaSemana: map['dia_semana'] is int ? map['dia_semana'] : int.tryParse('${map['dia_semana']}') ?? 0,
      horaInicio: map['hora_inicio'],
      horaFin: map['hora_fin'],
      nombreTurno: map['nombre_turno'],
      margenEntradaAntes: map['margen_entrada_antes'] is int
          ? map['margen_entrada_antes']
          : int.tryParse('${map['margen_entrada_antes'] ?? "10"}') ?? 10,
      margenEntradaDespues: map['margen_entrada_despues'] is int
          ? map['margen_entrada_despues']
          : int.tryParse('${map['margen_entrada_despues'] ?? "30"}') ?? 30,
    );
  }

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
      margenEntradaAntes: fields.length > 7 ? int.tryParse(fields[7]) ?? 10 : 10,
      margenEntradaDespues: fields.length > 8 ? int.tryParse(fields[8]) ?? 30 : 30,
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
      'margen_entrada_antes': margenEntradaAntes,
      'margen_entrada_despues': margenEntradaDespues,
    };
  }

  @override
  String toString() {
    return 'HorarioEmpleado{id: $id, dni: $dniEmpleado, empresa: $cifEmpresa, '
        'dia: $diaSemana, $horaInicio-$horaFin, turno: $nombreTurno, '
        'margenEntradaAntes: $margenEntradaAntes, margenEntradaDespues: $margenEntradaDespues}';
  }
}
