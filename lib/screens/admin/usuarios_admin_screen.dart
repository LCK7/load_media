import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({super.key});

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> empleados = [];
  bool isLoading = true;
  String? rolFiltro;

  final List<String> rolesDisponibles = ['admin', 'gestor', 'tecnico', 'cliente'];
  final List<String> rolesTrabajadores = ['admin', 'gestor', 'tecnico'];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => isLoading = true);
    try {
      var builder = supabase.from('usuarios').select('*');

      if (rolFiltro != null && rolFiltro != 'todos') {
        builder = builder.eq('rol', rolFiltro!);
      } else if (rolFiltro == null) {
        builder = builder.neq('rol', 'cliente');
      }

      final data = await builder.order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          empleados = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuarios: $e')),
      );
    }
  }

  Future<void> _crearNuevoUsuario({
    required String email,
    required String password,
    required String nombre,
    required String rol,
  }) async {
    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final newUserId = res.user?.id;
      if (newUserId == null) throw 'No se pudo obtener el ID del usuario.';

      await supabase.from('usuarios').insert({
        'id': newUserId,
        'nombre': nombre,
        'rol': rol,
        'terminos_aceptados': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario $nombre ($rol) creado.')),
      );
      _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear usuario: $e')),
      );
    }
  }

  Future<void> _restablecerPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace de restablecimiento enviado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mostrarModalRestablecerPassword(String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Restablecer Contraseña'),
        content: Text(
          'Se enviará un enlace de restablecimiento al correo:\n$email',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restablecerPassword(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarUsuario(String userId, String? nuevoNombre, String? nuevoRol) async {
    if (nuevoNombre == null && nuevoRol == null) return;

    try {
      final updateData = <String, dynamic>{};
      if (nuevoNombre != null) updateData['nombre'] = nuevoNombre;
      if (nuevoRol != null) updateData['rol'] = nuevoRol;

      await supabase.from('usuarios').update(updateData).eq('id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado.')),
      );

      _cargarUsuarios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ================================
  // 🔵 MODAL DE CREACIÓN DE USUARIO
  // ================================
  void _mostrarModalCreacion() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    String rolSeleccionado = "gestor";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setStateModal) => AlertDialog(
          title: const Text("Crear Nuevo Empleado"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: rolSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: rolesTrabajadores.map((rol) {
                  return DropdownMenuItem(
                    value: rol,
                    child: Text(rol.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setStateModal(() => rolSeleccionado = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _crearNuevoUsuario(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                  nombre: nombreController.text.trim(),
                  rol: rolSeleccionado,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Crear"),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // 🔵 MODAL DE EDICIÓN
  // ================================
  void _mostrarModalEdicion(Map<String, dynamic> usuario) {
    final TextEditingController nombreController =
        TextEditingController(text: usuario['nombre']);
    String nuevoRol = usuario['rol'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setStateModal) => AlertDialog(
          title: const Text('Editar Usuario'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                    labelText: 'Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: nuevoRol,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: rolesDisponibles.map((rol) {
                  return DropdownMenuItem(
                    value: rol,
                    child: Text(rol.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setStateModal(() => nuevoRol = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _actualizarUsuario(usuario['id'], nombreController.text, nuevoRol);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // 🔵 FILTRO VISUAL
  // ================================
  Widget _buildFiltroRoles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: DropdownButtonFormField<String>(
          value: rolFiltro,
          decoration: const InputDecoration(border: InputBorder.none),
          hint: const Text('Filtrar por rol...'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos los Empleados')),
            const DropdownMenuItem(value: 'todos', child: Text('Mostrar Todos (incluye Clientes)')),
            ...rolesDisponibles.map((rol) =>
                DropdownMenuItem(value: rol, child: Text(rol.toUpperCase()))),
          ],
          onChanged: (v) {
            setState(() => rolFiltro = v);
            _cargarUsuarios();
          },
        ),
      ),
    );
  }

  Color _getColorForRol(String rol) {
    switch (rol) {
      case 'admin':
        return Colors.red.shade600;
      case 'gestor':
        return Colors.indigo.shade600;
      case 'tecnico':
        return Colors.orange.shade700;
      case 'cliente':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  // ================================
  // 🔵 UI PRINCIPAL
  // ================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: Colors.blueGrey.shade700,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarUsuarios,
          )
        ],
      ),

      body: Column(
        children: [
          _buildFiltroRoles(),
          const Divider(height: 1),

          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))

          else if (empleados.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No se encontraron usuarios.'),
              ),
            )

          else
            Expanded(
              child: ListView.builder(
                itemCount: empleados.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) {
                  final usuario = empleados[i];
                  final isCurrentAdmin = supabase.auth.currentUser?.id == usuario['id'];
                  final userEmail = usuario['email'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                      shadowColor: Colors.blueGrey.shade100,
                      child: ListTile(
                        minVerticalPadding: 12,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: _getColorForRol(usuario['rol']),
                          child: Text(
                            usuario['rol'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        title: Text(
                          usuario['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Rol: ${usuario['rol'].toUpperCase()}"),
                              Text("ID: ${usuario['id'].substring(0, 8)}..."),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrentAdmin)
                              IconButton(
                                icon: const Icon(Icons.vpn_key, color: Colors.orange),
                                onPressed: () {
                                  if (userEmail != null) {
                                    _mostrarModalRestablecerPassword(userEmail);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Sin email registrado.")),
                                    );
                                  }
                                },
                              ),
                            if (!isCurrentAdmin)
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _mostrarModalEdicion(usuario),
                              ),
                            if (isCurrentAdmin)
                              const Icon(Icons.lock, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey.shade700,
        icon: const Icon(Icons.person_add),
        label: const Text('Crear Empleado'),
        onPressed: _mostrarModalCreacion,
      ),
    );
  }
}
