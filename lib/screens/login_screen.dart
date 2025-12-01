import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text("Iniciar sesión", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Correo", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    setState(() => loading = true);

                    final result = await auth.login(emailCtrl.text.trim(), passCtrl.text.trim());

                    setState(() => loading = false);

                    if (result == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario o contraseña incorrecta")));
                    } else {
                      // Navegación directa a Home con rol
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => Home(rol: result['rol'])),
                      );
                    }
                  },
                  child: Text(loading ? "Entrando..." : "Entrar"),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text("Crear cuenta"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
