import 'package:flutter/material.dart';
import 'fichar_screen.dart';
import 'login_screen.dart';
import 'historico_screen.dart';

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
            icon: Icon(Icons.check_box_outlined, size: 28),
            label: 'Fichar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.login, size: 28),
            label: 'Login',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 28),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }
}
