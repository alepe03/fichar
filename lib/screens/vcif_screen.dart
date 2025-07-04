import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; 
import '../services/empleado_service.dart';    
import '../services/sucursal_service.dart';     
import '../services/incidencia_service.dart';   

/// Pantalla para introducir el CIF de la empresa.
/// Si ya hay un CIF guardado, salta directamente al login.
class VCifScreen extends StatefulWidget {
  const VCifScreen({Key? key}) : super(key: key);

  @override
  State<VCifScreen> createState() => _VCifScreenState();
}

class _VCifScreenState extends State<VCifScreen> {
  // Controlador para el campo de texto del CIF
  final TextEditingController txtVCifCifEmpresa = TextEditingController();
  bool vaIsLoading = false;      // Estado de carga (muestra spinner)
  String? etiVCifError;          // Mensaje de error para el campo CIF

  @override
  void initState() {
    super.initState();
    _checkCifGuardado(); // Comprueba si ya hay un CIF guardado al iniciar
  }

  // Si ya hay un CIF guardado, navega directamente al login
  Future<void> _checkCifGuardado() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? VACif = prefs.getString('cif_empresa');
    if (VACif != null && VACif.isNotEmpty) {
      _irALogin(context);
    }
  }

  // Guarda el CIF introducido, descarga datos y navega al login
  Future<void> _guardarCifYContinuar() async {
    String VACif = txtVCifCifEmpresa.text.trim();
    if (VACif.isEmpty) {
      setState(() => etiVCifError = "Introduce el CIF de tu empresa");
      return;
    }

    setState(() {
      vaIsLoading = true; // Muestra el indicador de carga
      etiVCifError = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cif_empresa', VACif); // Guarda el CIF

    try {
      const token = '123456.abcd'; // Token fijo para la sincronización inicial

      // Descarga y guarda empleados, sucursales e incidencias usando el CIF y el token
      await EmpleadoService.descargarYGuardarEmpleados(VACif, token, BASE_URL);
      await SucursalService.descargarYGuardarSucursales(VACif, token, BASE_URL);
      await IncidenciaService.descargarYGuardarIncidencias(VACif, token, BASE_URL);

      _irALogin(context); // Si todo va bien, navega al login
    } catch (e, stacktrace) {
      print('ERROR descargando datos: $e');
      print('STACKTRACE: $stacktrace');
      setState(() {
        etiVCifError = 'Error descargando datos: $e'; // Muestra error si falla la descarga
      });
    } finally {
      setState(() => vaIsLoading = false); // Oculta el indicador de carga
    }
  }

  // Navega a la pantalla de login
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
            // Logo de la empresa
            Center(
              child: Image.asset(
                'assets/images/iconotrivalle.png',
                width: 120,   // Ajusta el tamaño a tu gusto
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),

            // Campo de texto para el CIF
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
            // Botón de continuar o indicador de carga
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
