import '../db/database_helper.dart';   // Importa el helper para la base de datos local
import '../models/empleado.dart';      // Importa el modelo de empleado

// Servicio de autenticación
class AuthService {
  // Método estático para login local
  // Busca un empleado en la base de datos local por usuario, contraseña y CIF de empresa
  static Future<Empleado?> loginLocal(String usuario, String password, String cifEmpresa) async {
    final db = await DatabaseHelper.instance.database; // Obtiene la instancia de la base de datos
    final result = await db.query(
      'empleados', // Tabla empleados
      where: 'usuario = ? AND password_hash = ? AND cif_empresa = ?', // Condición de búsqueda
      whereArgs: [usuario, password, cifEmpresa], // Argumentos para la consulta
      limit: 1, // Solo un resultado
    );
    if (result.isNotEmpty) {
      // Si encuentra un empleado, lo devuelve como objeto Empleado
      return Empleado.fromMap(result.first);
    }
    // Si no encuentra, devuelve null
    return null;
  }
}
