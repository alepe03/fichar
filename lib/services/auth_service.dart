import '../db/database_helper.dart';
import '../models/empleado.dart';

class AuthService {
  static Future<Empleado?> loginLocal(String usuario, String password, String cifEmpresa) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'empleados',
      where: 'usuario = ? AND password_hash = ? AND cif_empresa = ?',
      whereArgs: [usuario, password, cifEmpresa],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Empleado.fromMap(result.first);
    }
    return null;
  }
}
