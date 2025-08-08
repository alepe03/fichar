import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/database_helper.dart';
import '../models/empleado.dart';
import '../services/empleado_service.dart';  // <-- Importa el servicio para sincronizar empleados
import '../services/horarios_service.dart';  // <-- Importa el servicio para sincronizar horarios si lo tienes
import 'fichar_screen.dart';
import 'login_screen.dart';

class EmpresaLoginScreen extends StatefulWidget {
  const EmpresaLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmpresaLoginScreen> createState() => _EmpresaLoginScreenState();
}

class _EmpresaLoginScreenState extends State<EmpresaLoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> listaCifs = [];
  String? cifSeleccionado;

  bool vaIsLoading = false;
  String? vaErrorMessage;

  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _loadCifs();
  }

  Future<void> _loadCifs() async {
    final prefs = await SharedPreferences.getInstance();
    final cifs = prefs.getStringList('cif_empresa_list');
    final ultimoCif = prefs.getString('cif_empresa');
    if (cifs != null && cifs.isNotEmpty) {
      setState(() {
        listaCifs = cifs;
        cifSeleccionado = (ultimoCif != null && cifs.contains(ultimoCif))
            ? ultimoCif
            : cifs.first;
      });
    }
  }

  Future<Empleado?> _buscarEmpleadoPorIdPin(String id, String pin, String cif) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'empleados',
      where: 'id = ? AND pin_fichaje = ? AND cif_empresa = ?',
      whereArgs: [id, pin, cif],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Empleado.fromMap(res.first);
    }
    return null;
  }

  Future<void> _login({String? id, String? pin}) async {
    if (vaIsLoading) return;
    setState(() {
      vaIsLoading = true;
      vaErrorMessage = null;
    });

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => vaIsLoading = false);
      return;
    }
    if (cifSeleccionado == null || cifSeleccionado!.isEmpty) {
      setState(() {
        vaErrorMessage = "Debes seleccionar una empresa (CIF)";
        vaIsLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Sincronizar empleados antes de buscar localmente, igual que en login normal
    try {
      await EmpleadoService.sincronizarEmpleadosCompleto(
        prefs.getString('token') ?? '123456.abcd',
        prefs.getString('baseUrl') ?? 'https://www.trivalle.com/apiFichar/',
        cifSeleccionado!,
      );
    } catch (e) {
      print('Error sincronizando empleados antes de login empresa: $e');
    }

    final empleado = await _buscarEmpleadoPorIdPin(
      id ?? _idController.text.trim(),
      pin ?? _pinController.text,
      cifSeleccionado!,
    );

    if (empleado == null) {
      setState(() {
        vaErrorMessage = "ID o PIN incorrectos.";
        vaIsLoading = false;
      });
      return;
    }

    // Limpiar SharedPreferences excepto estado de fichaje para mantener continuidad
    await prefs.remove('usuario');
    await prefs.remove('nombre_empleado');
    await prefs.remove('dni_empleado');
    await prefs.remove('id_sucursal');
    await prefs.remove('rol');
    await prefs.remove('puede_localizar');
    // Comentado para mantener estado de fichaje:
    // await prefs.remove('ultimo_tipo_fichaje_${empleado.usuario}_${empleado.cifEmpresa}');
    // await prefs.remove('hora_entrada_${empleado.usuario}_${empleado.cifEmpresa}');

    await prefs.setString('cif_empresa', empleado.cifEmpresa);
    await prefs.setString('usuario', empleado.usuario);
    await prefs.setString('nombre_empleado', empleado.nombre ?? '');
    await prefs.setString('dni_empleado', empleado.dni ?? '');
    await prefs.setString('id_sucursal', '');
    await prefs.setInt('puede_localizar', empleado.puedeLocalizar);
    await prefs.setString('rol', empleado.rol ?? '');
    await prefs.setString('tipo_login', 'id_pin');

    // Opcional: sincronizar horarios o datos necesarios para fichaje
    try {
      await HorariosService.descargarYGuardarHorariosEmpresa(
        cifEmpresa: cifSeleccionado!,
        token: prefs.getString('token') ?? '',
        baseUrl: prefs.getString('baseUrl') ?? 'https://www.trivalle.com/apiFichar/',
      );
    } catch (e) {
      print('Error cargando horarios tras login empresa: $e');
    }

    if (!mounted) return;

    print('[LOGIN EMPRESA] Navegando a FicharScreen para usuario: ${empleado.usuario} (multi siempre true)');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => FicharScreen(
          esMultiFichaje: true,
          desdeLoginEmpresa: true, // <-- Aquí pasamos el flag
        ),
      ),
      (route) => false,
    );

    setState(() {
      vaIsLoading = false;
    });
  }

  // ------- QR SCAN LOGIC --------
  Future<void> _scanQrAndLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRViewScreen()),
    );

    if (result != null && result is String) {
      // Esperamos que el formato sea: id;pin
      final parts = result.split(';');
      if (parts.length >= 2) {
        final id = parts[0].trim();
        final pin = parts[1].trim();
        setState(() {
          _idController.text = id;
          _pinController.text = pin;
        });
        await _login(id: id, pin: pin);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR no válido. Esperado: id;pin")),
        );
      }
    }
  }
  // ------------------------------

  void _handleLogoTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 2), () {
      _tapCount = 0;
    });

    if (_tapCount == 3) {
      _tapCount = 0;
      _tapTimer?.cancel();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fichar con ID y PIN',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
            tooltip: "Fichar escaneando QR",
            onPressed: _scanQrAndLogin,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              width: ancho > 400 ? 400 : ancho * 0.95,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _handleLogoTap,
                      child: Image.asset('assets/images/iconotrivalle.png', width: 90, height: 90),
                    ),
                    const SizedBox(height: 24),
                    if (listaCifs.isEmpty)
                      const Text(
                        'No hay CIFs disponibles. Ve a la pantalla anterior para añadirlos.',
                        style: TextStyle(color: Colors.red),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Selecciona CIF',
                          labelStyle: const TextStyle(color: Colors.blue),
                          prefixIcon: const Icon(Icons.business, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        value: cifSeleccionado,
                        iconEnabledColor: Colors.blue,
                        dropdownColor: const Color(0xFFEAEAEA),
                        items: listaCifs
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(color: Colors.black)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => cifSeleccionado = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un CIF' : null,
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'ID de empleado',
                        prefixIcon: Icon(Icons.badge, color: Colors.blue),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? "Introduce el ID" : null,
                      enabled: !vaIsLoading,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'PIN de fichaje',
                        prefixIcon: Icon(Icons.password, color: Colors.blue),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? "Introduce el PIN" : null,
                      enabled: !vaIsLoading,
                    ),
                    const SizedBox(height: 28),
                    if (vaErrorMessage != null) ...[
                      Text(
                        vaErrorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: vaIsLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Fichar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            onPressed: vaIsLoading ? null : () => _login(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: vaIsLoading ? null : _scanQrAndLogin,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla para escanear QR con MOBILE_SCANNER
class QRViewScreen extends StatefulWidget {
  const QRViewScreen({Key? key}) : super(key: key);

  @override
  State<QRViewScreen> createState() => _QRViewScreenState();
}

class _QRViewScreenState extends State<QRViewScreen> {
  bool _isScanned = false;
  final MobileScannerController controller = MobileScannerController();
  bool _isFrontCamera = false; // Estado para la cámara

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final barcode = capture.barcodes.first;
    final code = barcode.rawValue;
    if (code != null && code.isNotEmpty) {
      _isScanned = true;
      controller.stop();
      Navigator.of(context).pop(code);
    }
  }

  void _toggleCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      controller.switchCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () {
                  controller.stop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              backgroundColor: Colors.blue.withOpacity(0.8),
              onPressed: _toggleCamera,
              child: Icon(_isFrontCamera ? Icons.camera_rear : Icons.camera_front),
            ),
          ),
        ],
      ),
    );
  }
}
