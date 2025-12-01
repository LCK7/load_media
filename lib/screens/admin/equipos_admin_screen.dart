import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EquiposAdminScreen extends StatefulWidget {
  const EquiposAdminScreen({super.key});

  @override
  State<EquiposAdminScreen> createState() => _EquiposAdminScreenState();
}

class _EquiposAdminScreenState extends State<EquiposAdminScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> equipos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarEquipos();
  }

  Future<void> cargarEquipos() async {
    final data = await supabase
        .from('equipos')
        .select('*')
        .order('created_at', ascending: false);

    setState(() {
      equipos = data;
      cargando = false;
    });
  }

  void abrirFormulario({Map<String, dynamic>? equipo}) {
    final nombreCtrl = TextEditingController(text: equipo?['nombre'] ?? '');
    final descripcionCtrl =
        TextEditingController(text: equipo?['descripcion'] ?? '');
    final imagenUrlCtrl =
        TextEditingController(text: equipo?['imagen_url'] ?? '');

    String estado = equipo?['estado'] ?? 'disponible';

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            equipo == null ? "Nuevo Equipo" : "Editar Equipo",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _styledInput(nombreCtrl, "Nombre del equipo"),
                const SizedBox(height: 12),
                _styledInput(descripcionCtrl, "Descripción", maxLines: 3),
                const SizedBox(height: 12),
                _styledInput(
                    imagenUrlCtrl, "URL de imagen (Supabase Storage)"),
                const SizedBox(height: 15),

                // Dropdown bonito
                DropdownButtonFormField<String>(
                  value: estado,
                  items: const [
                    DropdownMenuItem(
                        value: "disponible",
                        child: Text("Disponible")),
                    DropdownMenuItem(
                        value: "prestado", child: Text("Prestado")),
                    DropdownMenuItem(
                        value: "mantenimiento",
                        child: Text("Mantenimiento")),
                  ],
                  onChanged: (val) {
                    if (val != null) estado = val;
                  },
                  decoration: InputDecoration(
                    labelText: "Estado",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(equipo == null ? "Guardar" : "Actualizar"),
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final descripcion = descripcionCtrl.text.trim();
                final imagenUrl = imagenUrlCtrl.text.trim();

                if (nombre.isEmpty) return;

                if (equipo == null) {
                  await supabase.from('equipos').insert({
                    'nombre': nombre,
                    'descripcion': descripcion,
                    'imagen_url': imagenUrl,
                    'estado': estado,
                  });
                } else {
                  await supabase.from('equipos').update({
                    'nombre': nombre,
                    'descripcion': descripcion,
                    'imagen_url': imagenUrl,
                    'estado': estado,
                  }).eq('id', equipo['id']);
                }

                Navigator.pop(context);
                cargarEquipos();
              },
            )
          ],
        );
      },
    );
  }

  Widget _styledInput(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> eliminarEquipo(int id) async {
    await supabase.from('equipos').delete().eq('id', id);
    cargarEquipos();
  }

  Widget _chipEstado(String estado) {
    Color color;
    switch (estado) {
      case "prestado":
        color = Colors.orange;
        break;
      case "mantenimiento":
        color = Colors.redAccent;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: const Text(
          "Gestión de Equipos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, size: 28),
        onPressed: () => abrirFormulario(),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : equipos.isEmpty
              ? const Center(
                  child: Text(
                    "No hay equipos registrados",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: equipos.length,
                  itemBuilder: (_, index) {
                    final e = equipos[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: e['imagen_url'] != null &&
                                  e['imagen_url'].toString().isNotEmpty
                              ? Image.network(
                                  e['imagen_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.photo,
                                      color: Colors.grey),
                                ),
                        ),
                        title: Text(
                          e['nombre'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['descripcion'] ?? "Sin descripción",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _chipEstado(e['estado']),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => abrirFormulario(equipo: e),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => eliminarEquipo(e['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
