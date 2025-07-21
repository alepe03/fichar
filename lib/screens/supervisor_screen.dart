import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../screens/admin_screen.dart';
import '../screens/login_screen.dart'; // Importa para navegar

const Color kPrimaryBlue = Color.fromARGB(255, 33, 150, 243);

class SupervisorScreen extends StatefulWidget {
  final String cifEmpresa;

  const SupervisorScreen({Key? key, required this.cifEmpresa}) : super(key: key);

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  late AdminProvider _provider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = AdminProvider(widget.cifEmpresa);
    _loadData();
  }

  Future<void> _loadData() async {
    await _provider.cargarEmpleados();
    await _provider.cargarHistoricos();
    await _provider.cargarIncidencias();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _volverLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Panel Supervisor - Fichajes',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: kPrimaryBlue,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white), // Aquí el color blanco
            tooltip: 'Volver al Login',
            onPressed: _volverLogin,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : const FichajesTab(),
      ),
    );
  }
}
