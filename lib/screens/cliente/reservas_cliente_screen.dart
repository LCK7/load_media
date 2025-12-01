
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> reservas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarMisReservas();
  }

  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/60';
    if (path.startsWith('http')) return path;
    try {
      return supabase.storage.from('equipos').getPublicUrl(path);
    } catch (_) {
      return 'https://via.placeholder.com/60';
    }
  }

  Future<void> cargarMisReservas() async {
    final userId = supabase.auth.currentUser!.id;
    setState(() => cargando = true);

    try {
      final data = await supabase
          .from('reservas')
          .select('id, fecha_reserva, hora_inicio, hora_fin, estado, equipos(nombre, imagen_url)')
          .eq('usuario_id', userId)
          .order('fecha_reserva', ascending: false);

      setState(() {
        reservas = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reservas: ${e.toString()}')));
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Reservas 📆")),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : reservas.isEmpty
              ? const Center(child: Text("No tienes reservas activas"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: reservas.length,
                  itemBuilder: (context, index) {
                    final r = reservas[index];
                    final equipo = r['equipos'];

                    final String imageUrl = resolveImageUrl(equipo['imagen_url']);

                    final String fecha = r['fecha_reserva'] != null
                        ? DateFormat('dd/MMM/yyyy').format(DateTime.parse(r['fecha_reserva']))
                        : 'Fecha desconocida';
                    final String horario = (r['hora_inicio'] as String? ?? 'N/A').substring(0, 5) + ' - ' + (r['hora_fin'] as String? ?? 'N/A').substring(0, 5);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.devices, size: 50, color: Colors.grey);
                            },
                          ),
                        ),
                        title: Text(
                          equipo['nombre'] ?? 'Equipo sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Estado: ${r['estado']}"),
                            Text("Fecha: $fecha"),
                            Text("Horario: $horario"),
                          ],
                        ),
                        trailing: Icon(
                          r['estado'] == 'pendiente' ? Icons.hourglass_empty : 
                          r['estado'] == 'confirmada' ? Icons.check_circle : 
                          Icons.cancel,
                          color: r['estado'] == 'pendiente' ? Colors.orange : 
                                 r['estado'] == 'confirmada' ? Colors.green : 
                                 Colors.red,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}