import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../services/empleado_service.dart';
import '../services/sucursal_service.dart';
import '../services/incidencia_service.dart';

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
                width: 120,
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
                errorStyle: const TextStyle(color: Color(0xFFD32F2F)), // rojo menos saturado
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _guardarCifYContinuar(),
            ),
            const SizedBox(height: 40),  // Más espacio antes del botón
            vaIsLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 52,   // un poco más alto que el default
                    child: ElevatedButton(
                      onPressed: _guardarCifYContinuar,
                      child: const Text('Continuar', style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
