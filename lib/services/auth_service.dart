import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<String?> register({
    required String email,
    required String password,
    required String nombre,

  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return 'Error creando usuario';

      await supabase.from('usuarios').insert({
        'id': user.id,
        'nombre': nombre,
        'rol': 'cliente',        
        'terminos_aceptados': true,
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      final data = await supabase
          .from('usuarios')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;

      return {'id': user.id, 'rol': data['rol']};
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
