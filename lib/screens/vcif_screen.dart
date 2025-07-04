import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // Importa la constante BASE_URL
import '../services/empleado_service.dart';      // Servicio para empleados
import '../services/sucursal_service.dart';      // Servicio para sucursales
import '../services/incidencia_service.dart';    // Servicio para incidencias

/// Pantalla para introducir el CIF de la empresa.
class VCifScreen extends StatefulWidget {
  const VCifScreen({Key? key}) : super(key: key);

  @override
  State<VCifScreen> createState() => _VCifScreenState();
}

class _VCifScreenState extends State<VCifScreen> {
  final TextEditingController txtVCifCifEmpresa = TextEditingController();
  bool vaIsLoading = false;
  String? etiVCifError;

  @override
  void initState() {
    super.initState();
    _checkCifGuardado();
  }

  Future<void> _checkCifGuardado() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? VACif = prefs.getString('cif_empresa');
    if (VACif != null && VACif.isNotEmpty) {
      _irALogin(context);
    }
  }

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

      await EmpleadoService.descargarYGuardarEmpleados(VACif, token, BASE_URL);
      await SucursalService.descargarYGuardarSucursales(VACif, token, BASE_URL);
      await IncidenciaService.descargarYGuardarIncidencias(VACif, token, BASE_URL);

      _irALogin(context);
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
            Center(
              child: Image.asset(
                'assets/images/iconotrivalle.png',
                width: 120,   // Ajusta el tamaño a tu gusto
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),

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
