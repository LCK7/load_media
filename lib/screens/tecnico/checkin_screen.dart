import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DevolucionScreen extends StatefulWidget {
  const DevolucionScreen({super.key});

  @override
  State<DevolucionScreen> createState() => _DevolucionScreenState();
}

class _DevolucionScreenState extends State<DevolucionScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> prestamosPendientes = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarPrestamosPendientes();
  }

  // Carga las reservas CONFIRMADAS (prestadas) que están pendientes de Devolución.
  Future<void> cargarPrestamosPendientes() async {
    setState(() => cargando = true);
    try {
      // Trae las reservas cuyo estado es 'confirmada', ya que esto indica que el equipo fue prestado
      // y está esperando el check-in (devolución).
      final data = await supabase
          .from('reservas')
          .select('''
            id,
            fecha_reserva,
            hora_inicio,
            hora_fin,
            equipos(id, nombre, imagen_url, estado),
            usuarios(nombre)
          ''')
          .eq('estado', 'confirmada') // Filtra solo equipos prestados
          .order('fecha_reserva', ascending: true);
      
      if (!mounted) return;
      setState(() {
        prestamosPendientes = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando préstamos: ${e.toString()}')));
    }
  }

  // Función para registrar la DEVOLUCIÓN (Check-in)
  Future<void> registrarDevolucion({
    required int reservaId,
    required int equipoId,
    required String reporteDano,
    required bool tieneDano,
  }) async {
    final tecnicoId = supabase.auth.currentUser!.id;
    setState(() => cargando = true);

    try {
      // 1. Encontrar el registro de préstamo asociado a esta reserva.
      final prestamoExistente = await supabase
          .from('prestamos')
          .select('id')
          .eq('reserva_id', reservaId)
          .single();

      final prestamoId = prestamoExistente['id'];

      // 2. Actualizar el registro de préstamo existente con los datos de devolución.
      await supabase.from('prestamos').update({
        'recibido_por': tecnicoId, // El técnico es quien recibe el equipo
        'fecha_devolucion': DateTime.now().toIso8601String(),
        'reporte_dano': reporteDano.isNotEmpty ? reporteDano : null,
      }).eq('id', prestamoId); // Usamos el ID del préstamo encontrado

      // 3. Determinar y actualizar el estado del equipo
      final nuevoEstadoEquipo = tieneDano ? 'mantenimiento' : 'disponible';
      await supabase.from('equipos').update({
        'estado': nuevoEstadoEquipo,
      }).eq('id', equipoId);
      
      // 4. Actualizar estado de la reserva a 'finalizada'
      await supabase.from('reservas').update({
        'estado': 'finalizada',
      }).eq('id', reservaId);


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Devolución registrada. Equipo en estado: $nuevoEstadoEquipo')),
      );

      await cargarPrestamosPendientes(); // Recargar la lista
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al registrar devolución: ${e.toString()}')));
    } finally {
      setState(() => cargando = false);
    }
  }

  // Diálogo para ingresar detalles de la devolución
  Future<void> mostrarDialogoDevolucion(
      int reservaId, int equipoId, String equipoNombre) async {
    final reporteDanoController = TextEditingController();
    bool tieneDano = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text('Devolución: $equipoNombre'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reporteDanoController,
                    decoration: const InputDecoration(
                      labelText: 'Reporte de daño/Observaciones (Opcional)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('¿El equipo tiene daños?'),
                      Checkbox(
                        value: tieneDano,
                        onChanged: (bool? value) {
                          setStateSB(() {
                            tieneDano = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tieneDano && reporteDanoController.text.trim().isEmpty) {
                      // Se puede agregar una validación aquí si el daño es obligatorio
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Añade una descripción del daño.')));
                      return;
                    }
                    Navigator.of(context).pop();
                    registrarDevolucion(
                      reservaId: reservaId,
                      equipoId: equipoId,
                      reporteDano: reporteDanoController.text.trim(),
                      tieneDano: tieneDano,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar Devolución'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Función para resolver la URL de la imagen
  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/150';
    if (path.startsWith('http')) return path;
    try {
      return supabase.storage.from('equipos').getPublicUrl(path);
    } catch (_) {
      return 'https://via.placeholder.com/150';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Estado Vacío Mejorado para el Técnico
    final emptyState = Scaffold(
      appBar: AppBar(
        title: const Text('Check-in (Devolución) 🧑‍🔧'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sin devoluciones pendientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Todos los equipos prestados han sido devueltos.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    if (prestamosPendientes.isEmpty) {
      return emptyState;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in (Devolución) 🧑‍🔧'),
        backgroundColor: Colors.orange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: prestamosPendientes.length,
        itemBuilder: (context, index) {
          final reserva = prestamosPendientes[index];
          final equipo = reserva['equipos'];
          final cliente = reserva['usuarios'];
          final fechaReserva = DateTime.parse(reserva['fecha_reserva'] as String);
          final imageUrl = resolveImageUrl(equipo['imagen_url']);

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
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
              title: Text(equipo['nombre'] ?? 'Equipo'),
              subtitle: Text(
                  'Cliente: ${cliente['nombre']}\nFecha de Reserva: ${df.format(fechaReserva)}'),
              isThreeLine: true,
              trailing: ElevatedButton.icon(
                onPressed: () => mostrarDialogoDevolucion(
                  reserva['id'],
                  equipo['id'],
                  equipo['nombre'],
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.white),
                label: const Text('Devolver', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}