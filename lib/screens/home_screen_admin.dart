import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'fichar_screen.dart';
import 'login_screen.dart';
import 'admin_screen.dart';
import '../providers/admin_provider.dart'; // Ajusta la ruta según tu proyecto

class HomeScreenAdmin extends StatefulWidget {
  final String usuario;
  final String cifEmpresa;

  const HomeScreenAdmin({
    Key? key,
    required this.usuario,
    required this.cifEmpresa,
  }) : super(key: key);

  @override
  State<HomeScreenAdmin> createState() => _HomeScreenAdminState();
}

class _HomeScreenAdminState extends State<HomeScreenAdmin> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const FicharScreen(),
      const LoginScreen(),
      ChangeNotifierProvider(
        create: (_) => AdminProvider(widget.cifEmpresa),
        child: AdminScreen(cifEmpresa: widget.cifEmpresa),
      ),
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
        elevation: 0,
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
            icon: Icon(Icons.admin_panel_settings, size: 28),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}
