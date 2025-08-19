import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
      final token = DatabaseConfig.apiToken;
      final url = Uri.parse('$BASE_URL?Code=700&cif_empresa=$cif&Token=$token');
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.contains('OK')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _irALogin() {
    if (listaCifs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes añadir al menos un CIF antes de continuar'),
          backgroundColor: Colors.red,
        ),
      );
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
      final token = DatabaseConfig.apiToken;
      await Future.wait([
        EmpleadoService.descargarYGuardarEmpleados(nuevoCif, token, BASE_URL),
        SucursalService.descargarYGuardarSucursales(nuevoCif, token, BASE_URL),
        IncidenciaService.descargarYGuardarIncidencias(nuevoCif, token, BASE_URL),
      ]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error descargando datos: $e')),
      );
    } finally {
      setState(() => vaIsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ CIF $nuevoCif añadido correctamente')),
      );
    }
  }

  void _borrarCif(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFFEAEAEA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar CIF', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que quieres eliminar ${listaCifs[index]}?',
            style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                listaCifs.removeAt(index);
              });
              _guardarListaCifs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CIF eliminado')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editarCif(int index) {
    final controller = TextEditingController(text: listaCifs[index]);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFFEAEAEA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Modificar CIF', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nuevo CIF',
                prefixIcon: Icon(Icons.edit, color: Colors.blue),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
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
              setState(() => vaIsLoading = true);
              final existe = await validarCifEnServidor(cifEditado);
              if (!existe) {
                setState(() => vaIsLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El CIF no existe en la base de datos')),
                );
                return;
              }
              setState(() {
                listaCifs[index] = cifEditado;
              });
              await _guardarListaCifs();
              setState(() => vaIsLoading = false);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ CIF actualizado a $cifEditado')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // 🔹 Cierra teclado al pulsar fuera
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar CIFs'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Image.asset('assets/images/iconotrivalle.png', width: 100, height: 100),
                        const SizedBox(height: 24),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: txtNuevoCifController,
                                  decoration: InputDecoration(
                                    labelText: 'Introduce nuevo CIF',
                                    prefixIcon: const Icon(Icons.business, color: Colors.blue),
                                    errorText: etiVCifError,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _anadirNuevoCif(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: vaIsLoading ? null : _anadirNuevoCif,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    child: vaIsLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Añadir CIF'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        listaCifs.isEmpty
                            ? const Text('No hay CIFs añadidos.')
                            : Column(
                                children: listaCifs.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  String cif = entry.value;
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: const Icon(Icons.business, color: Colors.blue),
                                      title: Text(cif, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.orange),
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
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _irALogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Continuar al Login'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
