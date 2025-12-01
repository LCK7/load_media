import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestorReservasScreen extends StatefulWidget {
  const GestorReservasScreen({super.key});

  @override
  State<GestorReservasScreen> createState() => _GestorReservasScreenState();
}

class _GestorReservasScreenState extends State<GestorReservasScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> reservas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarReservasPendientes();
  }

  Future<void> cargarReservasPendientes() async {
    setState(() => cargando = true);
    try {
      final data = await supabase
          .from('reservas')
          .select('id, fecha_reserva, hora_inicio, hora_fin, estado, equipo_id, equipos(nombre, imagen_url), usuarios(nombre)')
          .eq('estado', 'pendiente')
          .order('fecha_reserva', ascending: true);

      if (!mounted) return;
      setState(() {
        reservas = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: ${e.toString()}')));
      setState(() => cargando = false);
    }
  }

  Future<void> aceptarReserva(int reservaId, int equipoId) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no autenticado.')));
      return;
    }

    try {
      await supabase.from('reservas').update({
        'estado': 'confirmada',
      }).eq('id', reservaId);

      await supabase.from('prestamos').insert({
        'reserva_id': reservaId,
        'entregado_por': userId,
        'fecha_entrega': DateTime.now().toIso8601String(),
      });
      
      await supabase.from('equipos').update({
        'estado': 'prestado',
      }).eq('id', equipoId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva confirmada. Préstamo registrado.')));
      cargarReservasPendientes();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al confirmar y registrar préstamo: ${e.toString()}')));
    }
  }

  // ❌ Rechaza la reserva y se asegura de que el equipo esté disponible
  Future<void> rechazarReserva(int reservaId, int equipoId) async {
    try {
      // 1. Cambia el estado de la reserva a cancelada
      await supabase.from('reservas').update({
        'estado': 'cancelada',
      }).eq('id', reservaId);
      
      // 2. Se asegura de que el equipo esté disponible (por si acaso estaba marcado como 'prestado' previamente por error)
      await supabase.from('equipos').update({
        'estado': 'disponible', 
      }).eq('id', equipoId);


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada.')));
      cargarReservasPendientes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar: ${e.toString()}')));
    }
  }

  // Función para resolver la URL de la imagen
  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/150';
    if (path.startsWith('http')) return path;
    try {
      // Ajusta 'equipos' si tu bucket de Storage tiene otro nombre
      return supabase.storage.from('equipos').getPublicUrl(path);
    } catch (_) {
      return 'https://via.placeholder.com/150';
    }
  }

  // Widget para el estado vacío (Mejora visual)
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          SizedBox(height: 16),
          Text(
            "¡Todo al día! 🎉",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "No hay reservas pendientes de aprobación.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reservas Pendientes 📝"),
        backgroundColor: Colors.blue,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : reservas.isEmpty
              ? _buildEmptyState() // Muestra el estado vacío mejorado
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: reservas.length,
                  itemBuilder: (context, index) {
                    final r = reservas[index];
                    final equipo = r['equipos'];
                    final usuario = r['usuarios'];
                    final imageUrl = resolveImageUrl(equipo['imagen_url']);

                    final horaInicio = (r['hora_inicio'] as String).substring(0, 5);
                    final horaFin = (r['hora_fin'] as String).substring(0, 5);
                    final fechaReserva = r['fecha_reserva'] ?? 'Fecha no disponible';

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.devices, size: 50, color: Colors.grey),
                          ),
                        ),
                        title: Text(
                          "${equipo['nombre']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Cliente: ${usuario['nombre']}"),
                            Text("Fecha de Reserva: $fechaReserva"),
                            Text("Horario Solicitado: $horaInicio - $horaFin"),
                            // Agregamos una etiqueta de estado para claridad
                            Chip(
                              label: Text(r['estado'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: Colors.orange[800],
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón ACEPTAR
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                              tooltip: 'Aceptar Reserva',
                              onPressed: () => aceptarReserva(r['id'], r['equipo_id']),
                            ),
                            // Botón RECHAZAR
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                              tooltip: 'Rechazar Reserva',
                              onPressed: () => rechazarReserva(r['id'], r['equipo_id']),
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