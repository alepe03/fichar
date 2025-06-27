import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // Importa la constante BASE_URLes es
import '../services/empleado_service.dart';
import '../services/sucursal_service.dart';
import '../services/incidencia_service.dart';

/// Pantalla para introducir el CIF de la empresa.
class VCifScreen extends StatefulWidget {
  const VCifScreen({Key? key}) : super(key: key);

  @override
  State<VCifScreen> createState() => _VCifScreenState();
}

class _VCifScreenState extends State<VCifScreen> {
  // Controlador para la caja de texto del CIF
  final TextEditingController txtVCifCifEmpresa = TextEditingController();

  // Estado de carga (true cuando se está guardando el CIF)
  bool vaIsLoading = false;
  // Mensaje de error
  String? etiVCifError;

  @override
  void initState() {
    super.initState();
    _checkCifGuardado();
  }

  /// Comprueba si ya hay un CIF guardado; si sí, salta al login directamente.
  Future<void> _checkCifGuardado() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? VACif = prefs.getString('cif_empresa');
    if (VACif != null && VACif.isNotEmpty) {
      _irALogin(context);
    }
  }

  /// Guarda el CIF introducido, descarga datos y navega al login.
  Future<void> _guardarCifYContinuar() async {
    String VACif = txtVCifCifEmpresa.text.trim();
    if (VACif.isEmpty) {
      setState(() => etiVCifError = "Introduce el CIF de tu empresa");
      return;
    }

    setState(() {
      vaIsLoading = true;
      etiVCifError = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cif_empresa', VACif);

    try {
      const token = '123456.abcd';

      // Sincronización inicial usando la constante global BASE_URL
      await EmpleadoService.descargarYGuardarEmpleados(VACif, token, BASE_URL);
      await SucursalService.descargarYGuardarSucursales(VACif, token, BASE_URL);
      await IncidenciaService.descargarYGuardarIncidencias(VACif, token, BASE_URL);

      _irALogin(context); // Solo si todo fue bien
    } catch (e, stacktrace) {
      print('ERROR descargando datos: $e');
      print('STACKTRACE: $stacktrace');
      setState(() {
        etiVCifError = 'Error descargando datos: $e';
      });
    } finally {
      setState(() => vaIsLoading = false);
    }
  }

  /// Navega a la pantalla de login.
  void _irALogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Introduce el CIF de la empresa'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: txtVCifCifEmpresa,
              decoration: InputDecoration(
                labelText: 'CIF de la empresa',
                errorText: etiVCifError,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _guardarCifYContinuar(),
            ),
            const SizedBox(height: 32),
            vaIsLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _guardarCifYContinuar,
                    child: const Text('Continuar'),
                  ),
          ],
        ),
      ),
    );
  }
}
