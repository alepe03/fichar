import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Import para peticiones HTTP
import '../config.dart';
import '../services/empleado_service.dart';
import '../services/sucursal_service.dart';
import '../services/incidencia_service.dart';

class VCifScreen extends StatefulWidget {
  const VCifScreen({Key? key}) : super(key: key);

  @override
  State<VCifScreen> createState() => _VCifScreenState();
}

class _VCifScreenState extends State<VCifScreen> {
  final TextEditingController txtNuevoCifController = TextEditingController();
  bool vaIsLoading = false;
  String? etiVCifError;

  List<String> listaCifs = [];
  static const String prefsKey = 'cif_empresa_list';

  @override
  void initState() {
    super.initState();
    _cargarCifsGuardados();
  }

  Future<void> _cargarCifsGuardados() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? cifsGuardados = prefs.getStringList(prefsKey);
    if (cifsGuardados != null && cifsGuardados.isNotEmpty) {
      setState(() {
        listaCifs = cifsGuardados;
      });
    }
  }

  Future<void> _guardarListaCifs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, listaCifs);
  }

  Future<bool> validarCifEnServidor(String cif) async {
    try {
      const token = '123456.abcd'; // Usa tu token real o gestiónalo mejor
      final url = Uri.parse('$BASE_URL?Code=700&cif_empresa=$cif&Token=$token');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Aquí asumo que si devuelve OK está bien, y si da ERROR no existe
        if (response.body.contains('OK')) {
          return true;
        }
      }
    } catch (e) {
      // Puedes loguear o manejar error aquí si quieres
    }
    return false;
  }

  void _irALogin() {
    if (listaCifs.isEmpty) {
      setState(() {
        etiVCifError = 'Debes añadir al menos un CIF antes de continuar.';
      });
      return;
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _anadirNuevoCif() async {
    final nuevoCif = txtNuevoCifController.text.trim();
    if (nuevoCif.isEmpty) {
      setState(() => etiVCifError = 'Introduce un CIF válido');
      return;
    }
    if (listaCifs.contains(nuevoCif)) {
      setState(() => etiVCifError = 'El CIF ya está en la lista');
      return;
    }

    setState(() {
      vaIsLoading = true;
      etiVCifError = null;
    });

    // Validar CIF en la API antes de añadirlo
    final existe = await validarCifEnServidor(nuevoCif);
    if (!existe) {
      setState(() {
        vaIsLoading = false;
        etiVCifError = 'El CIF no existe en la base de datos';
      });
      return;
    }

    setState(() {
      listaCifs.add(nuevoCif);
      txtNuevoCifController.clear();
    });
    await _guardarListaCifs();

    try {
      const token = '123456.abcd';

      await EmpleadoService.descargarYGuardarEmpleados(nuevoCif, token, BASE_URL);
      await SucursalService.descargarYGuardarSucursales(nuevoCif, token, BASE_URL);
      await IncidenciaService.descargarYGuardarIncidencias(nuevoCif, token, BASE_URL);
    } catch (e) {
      setState(() {
        etiVCifError = 'Error descargando datos para $nuevoCif: $e';
      });
    } finally {
      setState(() {
        vaIsLoading = false;
      });
    }
  }

  void _borrarCif(int index) {
    setState(() {
      listaCifs.removeAt(index);
    });
    _guardarListaCifs();
  }

  void _editarCif(int index) {
    final controller = TextEditingController(text: listaCifs[index]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modificar CIF'),
        content: TextField(
          controller: controller,
          maxLength: 10,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(hintText: 'Nuevo CIF'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final cifEditado = controller.text.trim();
              if (cifEditado.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Introduce un CIF válido')),
                );
                return;
              }
              if (listaCifs.contains(cifEditado) && cifEditado != listaCifs[index]) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El CIF ya está en la lista')),
                );
                return;
              }
              // Validar el CIF editado antes de guardar
              setState(() {
                vaIsLoading = true;
                etiVCifError = null;
              });
              final existe = await validarCifEnServidor(cifEditado);
              if (!existe) {
                setState(() {
                  vaIsLoading = false;
                  etiVCifError = 'El CIF no existe en la base de datos';
                });
                return;
              }
              setState(() {
                listaCifs[index] = cifEditado;
              });
              await _guardarListaCifs();
              setState(() {
                vaIsLoading = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar CIFs'),
        actions: [
          TextButton(
            onPressed: _irALogin,
            child: const Text('Continuar al Login', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Image.asset(
              'assets/images/iconotrivalle.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),

            // Input para nuevo CIF
            TextField(
              controller: txtNuevoCifController,
              decoration: InputDecoration(
                labelText: 'Nuevo CIF',
                errorText: etiVCifError,
                errorStyle: const TextStyle(color: Color(0xFFD32F2F)),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _anadirNuevoCif(),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            vaIsLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _anadirNuevoCif,
                    child: const Text('Añadir CIF'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  ),

            const SizedBox(height: 24),

            Expanded(
              child: listaCifs.isEmpty
                  ? const Center(child: Text('No hay CIFs añadidos.'))
                  : ListView.builder(
                      itemCount: listaCifs.length,
                      itemBuilder: (context, index) {
                        final cif = listaCifs[index];
                        return Card(
                          child: ListTile(
                            title: Text(cif),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editarCif(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _borrarCif(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _irALogin,
                child: const Text('Continuar al Login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
