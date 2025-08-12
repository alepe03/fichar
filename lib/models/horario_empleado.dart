class HorarioEmpleado {
  final int? id;
  final String dniEmpleado;
  final String cifEmpresa;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final String? nombreTurno;
  final int margenEntradaAntes;
  final int margenEntradaDespues;
  final String? horasOrdinarias;     // calculado en backend
  final int? horasOrdinariasMin;     // calculado en backend

  HorarioEmpleado({
    this.id,
    required this.dniEmpleado,
    required this.cifEmpresa,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    this.nombreTurno,
    this.margenEntradaAntes = 10,
    this.margenEntradaDespues = 30,
    this.horasOrdinarias,
    this.horasOrdinariasMin,
  });

  factory HorarioEmpleado.fromMap(Map<String, dynamic> map) {
    String? _s(dynamic v) => v?.toString();
    int? _i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

    return HorarioEmpleado(
      id: _i(map['id']),
      dniEmpleado: _s(map['dni_empleado']) ?? '',
      cifEmpresa: _s(map['cif_empresa']) ?? '',
      diaSemana: _i(map['dia_semana']) ?? 0,
      horaInicio: _s(map['hora_inicio']) ?? '',
      horaFin: _s(map['hora_fin']) ?? '',
      nombreTurno: _s(map['nombre_turno']),
      margenEntradaAntes: _i(map['margen_entrada_antes']) ?? 10,
      margenEntradaDespues: _i(map['margen_entrada_despues']) ?? 30,
      horasOrdinarias: _s(map['horas_ordinarias']),
      horasOrdinariasMin: _i(map['horas_ordinarias_min']),
    );
  }

  factory HorarioEmpleado.fromCsv(String line) {
    // Limpia CR/LF y divide
    final fields = line.replaceAll('\r', '').trimRight().split(';');

    String? getS(int i) => (i < fields.length ? fields[i] : null)?.trim();
    int? getI(int i) => int.tryParse(getS(i) ?? '');

    return HorarioEmpleado(
      id: getI(0),
      dniEmpleado: getS(1) ?? '',
      cifEmpresa: getS(2) ?? '',
      diaSemana: getI(3) ?? 0,
      horaInicio: getS(4) ?? '',
      horaFin: getS(5) ?? '',
      nombreTurno: getS(6),
      margenEntradaAntes: getI(7) ?? 10,
      margenEntradaDespues: getI(8) ?? 30,
      horasOrdinarias: getS(9),
      horasOrdinariasMin: getI(10),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
    // Importante: guardar lo que llega del backend para que la UI lo tenga
    if (horasOrdinarias != null) map['horas_ordinarias'] = horasOrdinarias;
    if (horasOrdinariasMin != null) map['horas_ordinarias_min'] = horasOrdinariasMin;
    return map;
  }

  @override
  String toString() {
    return 'HorarioEmpleado{id: $id, dni: $dniEmpleado, empresa: $cifEmpresa, '
        'dia: $diaSemana, $horaInicio-$horaFin, turno: $nombreTurno, '
        'margenEntradaAntes: $margenEntradaAntes, margenEntradaDespues: $margenEntradaDespues, '
        'horasOrdinarias: $horasOrdinarias, horasOrdinariasMin: $horasOrdinariasMin}';
  }
}


