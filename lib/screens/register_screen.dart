import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  bool loading = false;

  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Crear cuenta", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre completo", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Correo", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    setState(() => loading = true);

                    final error = await auth.register(
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                      nombre: nombreCtrl.text.trim(),
                    );

                    setState(() => loading = false);

                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    } else {
                      // Después de registrar → ir al login
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: Text(loading ? "Creando..." : "Registrarse"),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Ya tengo cuenta"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
