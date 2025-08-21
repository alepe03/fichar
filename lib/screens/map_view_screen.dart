import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapViewScreen extends StatelessWidget {
  final String coordenadas;
  final String titulo;

  const MapViewScreen({
    Key? key,
    required this.coordenadas,
    required this.titulo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Parsear coordenadas
    final coords = coordenadas.split(',');
    if (coords.length != 2) {
      return Scaffold(
        appBar: AppBar(
          title: Text(titulo),
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Formato de coordenadas inválido'),
        ),
      );
    }

    final lat = double.tryParse(coords[0].trim());
    final lon = double.tryParse(coords[1].trim());

    if (lat == null || lon == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(titulo),
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Coordenadas inválidas'),
        ),
      );
    }

    final position = LatLng(lat, lon);

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Abrir en Google Maps',
            onPressed: () => _abrirGoogleMaps(lat, lon),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: position,
          initialZoom: 16.0,
          minZoom: 10.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.fichar',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 60,
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _abrirGoogleMaps(lat, lon),
          backgroundColor: Colors.green.shade600,
          elevation: 0,
          child: const Icon(Icons.map, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _abrirGoogleMaps(double lat, double lon) async {
    final url = 'https://www.google.com/maps?q=$lat,$lon';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Error silencioso
    }
  }
}
