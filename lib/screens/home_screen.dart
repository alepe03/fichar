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

  Widget _buildIcon(IconData icon, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: selected ? Colors.blue : Colors.grey[600],
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Importante para que la barra se superponga sin cortar
      body: _screens[_selectedIndex],

      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () => _onItemTapped(0),
              behavior: HitTestBehavior.opaque,
              child: _buildIcon(Icons.check_box_outlined, _selectedIndex == 0),
            ),
            GestureDetector(
              onTap: () => _onItemTapped(1),
              behavior: HitTestBehavior.opaque,
              child: _buildIcon(Icons.login, _selectedIndex == 1),
            ),
            GestureDetector(
              onTap: () => _onItemTapped(2),
              behavior: HitTestBehavior.opaque,
              child: _buildIcon(Icons.history, _selectedIndex == 2),
            ),
          ],
        ),
      ),
    );
  }
}
