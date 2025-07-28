import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}.${info.buildNumber}';
    });
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Logo Trivallé
              Image.asset(
                'assets/images/trivalle.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // Versión
              Text(
                'V $_version',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Desarrollador
              const Text(
                'Desarrollado y distribuido por Trivallé, S.L.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Dirección
              const Text(
                'Paseo de las Araucarias, 18\n38300 - La Orotava\nSanta Cruz de Tenerife',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Teléfono
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

              // Email
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

              // Web
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
