import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart'; // Importa la constante BASE_URL
import '../models/historico.dart'; // Modelo de fichaje
import '../services/historico_service.dart'; // Servicios para guardar fichajes

// Función utilidad: Devuelve la fecha y hora actual en formato MySQL (YYYY-MM-DD HH:MM:SS)
String nowToMySQL() {
  final now = DateTime.now();
  return "${now.year.toString().padLeft(4, '0')}-"
         "${now.month.toString().padLeft(2, '0')}-"
         "${now.day.toString().padLeft(2, '0')} "
         "${now.hour.toString().padLeft(2, '0')}:"
         "${now.minute.toString().padLeft(2, '0')}:"
         "${now.second.toString().padLeft(2, '0')}";
}

// Pantalla principal para fichar (entrada, salida, incidencia)
class FicharScreen extends StatefulWidget {
  const FicharScreen({Key? key}) : super(key: key);

  @override
  State<FicharScreen> createState() => _FicharScreenState();
}

class _FicharScreenState extends State<FicharScreen> {
  final TextEditingController txtObservaciones = TextEditingController(); // Observaciones para incidencias

  // Variables de configuración y usuario
  late String cifEmpresa;
  late String token;
  late String usuario;
  late String nombreEmpleado;   
  late String dniEmpleado;      
  late String idSucursal;       

  String vaUltimaAccion = ''; // Guarda la última acción realizada

  @override
  void initState() {
    super.initState();
    _loadConfig(); // Carga la configuración y datos del usuario al iniciar
  }

  // Carga los datos guardados en SharedPreferences
  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cifEmpresa     = prefs.getString('cif_empresa')     ?? '';
      token          = prefs.getString('token')           ?? '';
      usuario        = prefs.getString('usuario')         ?? '';
      nombreEmpleado = prefs.getString('nombre_empleado') ?? '';
      dniEmpleado    = prefs.getString('dni_empleado')    ?? '';
      idSucursal     = prefs.getString('id_sucursal')     ?? '';
    });
    print('[CONFIG] cifEmpresa: $cifEmpresa');
    print('[CONFIG] token: $token');
    print('[CONFIG] usuario: $usuario');
    print('[CONFIG] nombreEmpleado: $nombreEmpleado');
    print('[CONFIG] dniEmpleado: $dniEmpleado');
    print('[CONFIG] idSucursal: $idSucursal');
  }

  // Registra un fichaje (entrada, salida o incidencia)
  Future<void> _registrarFichaje(String tipo, {String? observaciones}) async {
    final fechaActual = nowToMySQL();

    // Crea el objeto historico con los datos del fichaje
    final historico = Historico(
      id: 0,
      cifEmpresa: cifEmpresa,
      usuario: usuario,
      fechaEntrada: tipo == 'Salida' ? '' : fechaActual,
      fechaSalida: tipo == 'Salida' ? fechaActual : null,
      tipo: tipo,
      incidenciaCodigo: null,
      observaciones: observaciones,
      nombreEmpleado: nombreEmpleado,
      dniEmpleado: dniEmpleado,
      idSucursal: idSucursal,
    );

    // 1) Guarda el fichaje localmente
    print('VOY A GUARDAR LOCAL');
    print('DATOS A GUARDAR: ${historico.toMap()}');
    await HistoricoService.guardarFichajeLocal(historico);
    print('LOCAL GUARDADO');

    // 2) Intenta guardar el fichaje en la nube
    print('VOY A GUARDAR EN NUBE: $tipo');
    try {
      await HistoricoService.guardarFichajeRemoto(
        historico,
        token,
        BASE_URL,
        'qame400',
      );
      print('GUARDADO REMOTO OK');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tipo registrada (online)')),
      );
    } catch (e) {
      print('ERROR AL GUARDAR EN NUBE: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tipo guardada localmente')),
      );
    }

    setState(() => vaUltimaAccion = tipo); // Actualiza la última acción
  }

  // Métodos para cada tipo de fichaje
  void _onEntrada() => _registrarFichaje('Entrada');
  void _onSalida()  => _registrarFichaje('Salida');

  // Muestra un diálogo para registrar una incidencia
  void _onIncidencia() {
    showDialog(
      context: context,
      builder: (_) {
        bool confirmado = false;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Registrar incidencia',
                      style: TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    // Campo de texto para observaciones
                    TextField(
                      controller: txtObservaciones,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    // Checkbox de confirmación
                    CheckboxListTile(
                      value: confirmado,
                      onChanged: (v) => setStateDialog(() => confirmado = v ?? false),
                      title: const Text('Confirmo la incidencia'),
                      activeColor: Colors.blue,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
                    // Botones de cancelar y registrar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          ),
                          child: const Text('Registrar'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _registrarFichaje(
                              'Incidencia',
                              observaciones: txtObservaciones.text.trim(),
                            );
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    txtObservaciones.dispose(); // Libera el controlador de texto
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          width: ancho > 400 ? 400 : ancho * 0.97,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [ BoxShadow(color: Colors.blue.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 7)) ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work, size: 54, color: Colors.blue),
              const SizedBox(height: 10),
              const Text('¿Qué quieres hacer?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 35),

              // Botón de fichar entrada
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Fichar entrada'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _onEntrada,
                ),
              ),
              const SizedBox(height: 18),

              // Botón de fichar salida
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Fichar salida'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _onSalida,
                ),
              ),
              const SizedBox(height: 18),

              // Botón de registrar incidencia
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Registrar incidencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _onIncidencia,
                ),
              ),
              const SizedBox(height: 30),

              // Muestra la última acción realizada si existe
              if (vaUltimaAccion.isNotEmpty)
                Text(
                  'Última acción: $vaUltimaAccion',
                  style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
