/*import 'package:hive/hive.dart';
import '../models/user.dart';
import 'api_service.dart';
*/
/// Descarga y guarda los usuarios en Hive, usando el token y productorId.
/*Future<void> syncUsers(String token, int productorId) async {
  final users = await ApiService.getUsers(token, productorId);
  var boxUsers = await Hive.openBox<User>('users');
  await boxUsers.clear();
  for (var u in users) {
    await boxUsers.put(
      u['id'],
      User(
        id: u['id'],
        name: u['name'],
        email: u['email'],
        password: u['password'],
        productorId: u['productor_id'],
      ),
    );
  }
}*/
