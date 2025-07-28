import 'package:flutter/material.dart';
import 'fichar_screen.dart';
import 'login_screen.dart';
import 'historico_screen.dart';
import 'about_screen.dart'; // <-- Importa tu nueva pantalla

class HomeScreen extends StatefulWidget {
  final String usuario;
  final String cifEmpresa;

  const HomeScreen({
    Key? key,
    required this.usuario,
    required this.cifEmpresa,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const FicharScreen(),
      const LoginScreen(),
      HistoricoScreen(usuario: widget.usuario, cifEmpresa: widget.cifEmpresa),
      const AboutScreen(), // <-- Añadida al final
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 0, // sin sombra
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint_outlined, size: 28),
            label: 'Fichar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            label: 'Login',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt, size: 28),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline, size: 28),
            label: 'Acerca',
          ),
        ],
      ),
    );
  }
}
