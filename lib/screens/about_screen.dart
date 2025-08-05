import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla "Acerca de" que muestra información de la app y contacto de la empresa
class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = ''; // Almacena la versión de la app

  @override
  void initState() {
    super.initState();
    _loadVersion(); // Carga la versión al iniciar la pantalla
  }

  /// Obtiene la versión y build de la app usando package_info_plus
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}.${info.buildNumber}';
    });
  }

  /// Lanza una URL (teléfono, email o web) usando url_launcher
  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'), // Título de la pantalla
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Logo de la empresa
              Image.asset(
                'assets/images/trivalle.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // Muestra la versión de la app
              Text(
                'V $_version',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Nombre del desarrollador/distribuidor
              const Text(
                'Desarrollado y distribuido por Trivalle, S.L.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Dirección física de la empresa
              const Text(
                'Paseo de las Araucarias, 18\n38300 - La Orotava\nSanta Cruz de Tenerife',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Teléfono (tap para llamar)
              GestureDetector(
                onTap: () => _launchUrl('tel:+34922328175'),
                child: const Text(
                  'Tel: 922 328 175',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Email (tap para enviar correo)
              GestureDetector(
                onTap: () => _launchUrl('mailto:info@trivalle.com'),
                child: const Text(
                  'Email: info@trivalle.com',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Web (tap para abrir navegador)
              GestureDetector(
                onTap: () => _launchUrl('https://www.trivalle.com'),
                child: const Text(
                  'www.trivalle.com',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
