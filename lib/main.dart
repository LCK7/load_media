import 'package:flutter/material.dart';
import 'package:load_media/screens/gestor/gestor_reservas_screen.dart';
import 'package:load_media/screens/tecnico/checkin_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';

// Cliente
import 'screens/cliente/catalogo_cliente_screen.dart';
import 'screens/cliente/reservas_cliente_screen.dart';
import 'screens/cliente/perfil_cliente_screen.dart';
import 'screens/cliente/carrito_screen.dart';

// Técnico
import 'screens/tecnico/reparaciones_screen.dart';

// Admin
import 'screens/admin/equipos_admin_screen.dart';
import 'screens/admin/usuarios_admin_screen.dart';

// Gestor
import 'screens/gestor/multas_screen.dart';
import 'screens/gestor/historial_prestamos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dbdwhktqdnmtkobcqthv.supabase.co',
    anonKey: 'sb_publishable_Whb2JEvOepfDhpz6aG4gVQ_94mXnMHl',
  );

  runApp(const LoanMediaApp());
}

class LoanMediaApp extends StatelessWidget {
  const LoanMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoanMedia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.blue[100],
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.blue[200],
          selectedItemColor: Colors.blue[900],
          unselectedItemColor: Colors.blue[700],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  String? _rol;

  @override
  void initState() {
    super.initState();
    verificarSesion();
  }

  Future<void> verificarSesion() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      setState(() {
        _rol = null;
        _loading = false;
      });
      return;
    }

    final data = await Supabase.instance.client
        .from('usuarios')
        .select('rol')
        .eq('id', user.id)
        .maybeSingle();

    String? rol = data?['rol']?.toString().toLowerCase().trim();

    setState(() {
      _rol = rol;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rol == null) return const LoginScreen();

    return Home(rol: _rol!);
  }
}

class Home extends StatefulWidget {
  final String rol;
  const Home({super.key, required this.rol});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    late final List<Widget> pages;
    late final List<BottomNavigationBarItem> nav;

    switch (widget.rol) {
      case "cliente":
        pages = const [
          CatalogoClienteScreen(),
          CarritoScreen(),
          MisReservasScreen(),
          PerfilClienteScreen(),
        ];
        nav = const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Catálogo"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Carrito"),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: "Reservas"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ];
        break;

      case "tecnico":
        pages = const [
          DevolucionScreen(),
          ReparacionesScreen(),
          PerfilClienteScreen(),
        ];
        nav = const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Devolución"),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: "Reparaciones"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ];
        break;

      case "gestor":
        pages = const [
          GestorReservasScreen(),
          HistorialPrestamosScreen(),
          MultasScreen(),
          PerfilClienteScreen(),
        ];
        nav = const [
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: "Gestor Reservas"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Multas"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ];
        break;

      case "admin":
        pages = const [
          CatalogoClienteScreen(),
          MisReservasScreen(),
          CarritoScreen(),
          PerfilClienteScreen(),
          HistorialPrestamosScreen(),
          MultasScreen(),
        ];
        nav = const [
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Catálogo"),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: "Reservas"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Carrito"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Historial"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Multas"),
        ];
        break;

      default:
        pages = const [Center(child: Text("Error: rol no válido"))];
        nav = const [
          BottomNavigationBarItem(icon: Icon(Icons.error), label: "Error")
        ];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("LoanMedia"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      drawer: widget.rol == "admin"
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue),
                    child: Text(
                      'Admin Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: const Text('Equipos'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const EquiposAdminScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Usuarios'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const UsuariosAdminScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.book_online),
                    title: const Text('Reservas (Aprobación)'),
                    // CORRECCIÓN 1: Usamos GestorReservasScreen para la aprobación
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const GestorReservasScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_turned_in),
                    title: const Text('Devoluciones (Check-In)'),
                    // CORRECCIÓN 2: Usamos CheckoutScreen para la devolución
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const DevolucionScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.build),
                    title: const Text('Reparaciones'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const ReparacionesScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.build),
                    title: const Text('Multas'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const MultasScreen())),
                  ),
                ],
              ),
            )
          : null,
      body: pages[pageIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: pageIndex,
        onTap: (i) => setState(() => pageIndex = i),
        items: nav,
      ),
    );
  }
}