import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/database_helper.dart';
import '../models/empleado.dart';
import '../services/empleado_service.dart';  // <-- Importa el servicio para sincronizar empleados
import '../services/horarios_service.dart';  // <-- Importa el servicio para sincronizar horarios si lo tienes
import '../config.dart'; // Para DatabaseConfig
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

  String? cifSeleccionado;

  bool vaIsLoading = false;
  String? vaErrorMessage;

  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _loadCifActivo();
  }

  Future<void> _loadCifActivo() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoCif = prefs.getString('cif_empresa');
    setState(() {
      cifSeleccionado = (ultimoCif != null && ultimoCif.isNotEmpty) ? ultimoCif : null;
    });
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
        vaErrorMessage = "No se encontró CIF activo. Inicia sesión normal primero para guardar el CIF.";
        vaIsLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1) Sincronizar empleados como en el login normal
    try {
      await EmpleadoService.sincronizarEmpleadosCompleto(
        prefs.getString('token') ?? DatabaseConfig.apiToken,
        prefs.getString('baseUrl') ?? 'https://www.trivalle.com/apiFichar/',
        cifSeleccionado!,
      );
    } catch (e) {
      // No bloqueamos el login por esto
      // ignore: avoid_print
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

    // Limpiar algunas prefs (manteniendo estado de fichaje si lo usas)
    await prefs.remove('usuario');
    await prefs.remove('nombre_empleado');
    await prefs.remove('dni_empleado');
    await prefs.remove('id_sucursal');
    await prefs.remove('rol');
    await prefs.remove('puede_localizar');

    await prefs.setString('cif_empresa', empleado.cifEmpresa);
    await prefs.setString('usuario', empleado.usuario);
    await prefs.setString('nombre_empleado', empleado.nombre ?? '');
    await prefs.setString('dni_empleado', empleado.dni ?? '');
    await prefs.setString('id_sucursal', '');
    await prefs.setInt('puede_localizar', empleado.puedeLocalizar);
    await prefs.setString('rol', empleado.rol ?? '');
    await prefs.setString('tipo_login', 'id_pin');

    // 2) (Opcional) sincronizar horarios
    try {
      await HorariosService.descargarYGuardarHorariosEmpresa(
        cifEmpresa: cifSeleccionado!,
        token: prefs.getString('token') ?? '',
        baseUrl: prefs.getString('baseUrl') ?? 'https://www.trivalle.com/apiFichar/',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error cargando horarios tras login empresa: $e');
    }

    if (!mounted) return;

    // Navegar a Fichar
    // ignore: avoid_print
    print('[LOGIN EMPRESA] Navegando a FicharScreen para usuario: ${empleado.usuario} (multi siempre true)');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => FicharScreen(
          esMultiFichaje: true,
          desdeLoginEmpresa: true,
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
      // Esperamos: id;pin
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
    final hayCif = cifSeleccionado != null && cifSeleccionado!.isNotEmpty;

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
                    const SizedBox(height: 16),
                    if (!hayCif)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'No hay CIF activo. Haz login normal primero para registrar el CIF.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.business, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              cifSeleccionado!,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
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
                            onPressed: (!vaIsLoading && hayCif) ? () => _login() : null,
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

// =============== Pantalla para escanear QR con MOBILE_SCANNER ===============
class QRViewScreen extends StatefulWidget {
  const QRViewScreen({Key? key}) : super(key: key);

  @override
  State<QRViewScreen> createState() => _QRViewScreenState();
}

class _QRViewScreenState extends State<QRViewScreen> {
  bool _isScanned = false;

  // Cámara frontal por defecto
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.front,
    // Opcionalmente puedes ajustar:
    // detectionSpeed: DetectionSpeed.noDuplicates,
    // torchEnabled: false,
  );

  // Para icono del botón
  bool _isFrontCamera = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final barcode = capture.barcodes.firstOrNull; // evita excepciones si viene vacío
    final code = barcode?.rawValue;
    if (code != null && code.isNotEmpty) {
      _isScanned = true;
      controller.stop();
      Navigator.of(context).pop(code);
    }
  }

  Future<void> _toggleCamera() async {
    await controller.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
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
                tooltip: 'Cerrar',
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              backgroundColor: Colors.blue.withOpacity(0.85),
              onPressed: _toggleCamera,
              child: Icon(_isFrontCamera ? Icons.camera_rear : Icons.camera_front),
              tooltip: _isFrontCamera ? 'Cambiar a trasera' : 'Cambiar a frontal',
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Helper extension para evitar crashes si no hay barcodes =====
extension _SafeFirst<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


