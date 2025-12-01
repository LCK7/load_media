// lib/screens/cliente/carrito_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> carrito = [];
  bool cargando = true;

  DateTime? fechaInicio;
  DateTime? fechaFin;

  @override
  void initState() {
    super.initState();
    cargarCarrito();
  }

  Future<void> cargarCarrito() async {
    setState(() => cargando = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      // Usamos un join (referencia) para obtener los datos del equipo
      final data = await supabase.from('carrito').select('''
        id,
        dias_prestamo,
        created_at,
        equipos (
          id,
          nombre,
          descripcion,
          imagen_url,
          estado,
          created_at
        )
      ''').eq('user_id', userId);

      if (!mounted) return;
      setState(() {
        carrito = (data as List<dynamic>?) ?? [];
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      // Solo mostramos error si no es un error de RLS o autenticación (ej: si el usuario no está logueado)
      if (supabase.auth.currentUser != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error cargando carrito: $e')));
      }
    }
  }

  String resolveImagenUrl(String? imagenUrl) {
    if (imagenUrl == null || imagenUrl.isEmpty) return '';
    final s = imagenUrl.trim();
    if (s.startsWith('http')) return s;
    
    try {
      return Supabase.instance.client.storage.from('equipos').getPublicUrl(s);
    } catch (_) {
      return '';
    }
  }

  Future<void> eliminarItem(dynamic carritoId) async {
    try {
      await supabase.from('carrito').delete().eq('id', carritoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item eliminado')));
      await cargarCarrito();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error eliminando: $e')));
    }
  }

  Future<void> seleccionarRangoFechas() async {
    final now = DateTime.now();
    
    final pickedInicio = await showDatePicker(
      context: context,
      initialDate: fechaInicio ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedInicio == null) return;

    // Selector de Fecha de Fin
    final pickedFin = await showDatePicker(
      context: context,
      initialDate: fechaFin ?? pickedInicio.add(const Duration(days: 1)),
      firstDate: pickedInicio,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedFin == null) return;

    if (!mounted) return;
    setState(() {
      fechaInicio = pickedInicio;
      fechaFin = pickedFin;
    });
  }
  Future<void> reservarTodos() async {
    if (carrito.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Carrito vacío')));
      return;
    }
    if (fechaInicio == null || fechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona fecha inicio y fin')));
      return;
    }

    final userId = supabase.auth.currentUser!.id;
    const horaInicio = '09:00:00';
    const horaFin = '17:00:00';
    final df = DateFormat('yyyy-MM-dd'); // Formato para Supabase

    setState(() => cargando = true);

    try {
      for (final item in carrito) {
        final equipo = item['equipos'];
        final equipoId = equipo['id'];

        await supabase.from('reservas').insert({
          'usuario_id': userId,
          'equipo_id': equipoId,
          'fecha_reserva': df.format(fechaInicio!),
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'estado': 'pendiente',
        });
        
      }

      await supabase.from('carrito').delete().eq('user_id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reservas creadas y pendientes de aprobación.')),
      );

      await cargarCarrito();
      setState(() {
        fechaInicio = null;
        fechaFin = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creando reservas: $e')));
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dfPretty = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito 🛒'),
        backgroundColor: Colors.blue,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : carrito.isEmpty
              ? const Center(child: Text('Tu carrito está vacío'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: carrito.length,
                        itemBuilder: (context, index) {
                          final item = carrito[index];
                          final equipo = (item['equipos'] ?? {}) as Map<String, dynamic>;
                          final imagenUrl = resolveImagenUrl(equipo['imagen_url'] as String?);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imagenUrl.isNotEmpty
                                    ? Image.network(
                                        imagenUrl,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image, size: 64),
                                      )
                                    : const Icon(Icons.photo, size: 64, color: Colors.grey),
                              ),
                              title: Text(equipo['nombre'] ?? 'Equipo'),
                              subtitle: Text('Estado actual: ${equipo['estado'] ?? '—'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => eliminarItem(item['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 📅 Sección de Fechas y Botón de Reserva
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border(top: BorderSide(color: Colors.blue.shade200)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: seleccionarRangoFechas,
                                  icon: const Icon(Icons.calendar_month, color: Colors.blue),
                                  label: Text(
                                    fechaInicio == null
                                        ? 'Seleccionar Fechas de Préstamo'
                                        : '${dfPretty.format(fechaInicio!)} → ${dfPretty.format(fechaFin!)}',
                                    style: TextStyle(color: Colors.blue.shade800),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.blue.shade200),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: reservarTodos,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text(
                                'Confirmar Reservas (Enviar Solicitud)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}