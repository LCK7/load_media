import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReparacionesScreen extends StatefulWidget {
  const ReparacionesScreen({super.key});

  @override
  State<ReparacionesScreen> createState() => _ReparacionesScreenState();
}

class _ReparacionesScreenState extends State<ReparacionesScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> equiposEnMantenimiento = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarEquiposEnMantenimiento();
  }

  Future<Map<String, dynamic>> obtenerUltimoReporte(int equipoId) async {
    try {
      final data = await supabase
          .from('prestamos')
          .select('reporte_dano, fecha_devolucion, recibido_por(nombre), reservas!inner(equipo_id)')
          .eq('reservas.equipo_id', equipoId) 
          .not('reporte_dano', 'is', null)
          .order('fecha_devolucion', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        final tecnicoNombre = data['recibido_por']?['nombre'] ?? 'Técnico desconocido'; 
        
        return {
          'ultimo_reporte': data['reporte_dano']?.toString() ?? 'Sin detalle de daño',
          'fecha_reporte': data['fecha_devolucion'] != null
              ? DateTime.parse(data['fecha_devolucion'].toString())
              : null,
          'recibido_por_nombre': tecnicoNombre, 
        };
      }

      return {
        'ultimo_reporte': 'Sin historial de daños registrado.',
        'fecha_reporte': null,
        'recibido_por_nombre': 'N/A'
      };
    } catch (e) {
      print('--- ERROR SUPABASE al obtener reporte para Equipo ID $equipoId ---');
      print(e);
      print('------------------------------------------------------------------');
      
      return {
        'ultimo_reporte': 'Error al cargar historial. Revisar la consola.',
        'fecha_reporte': null,
        'recibido_por_nombre': 'Error'
      };
    }
  }

  Future<void> cargarEquiposEnMantenimiento() async {
    setState(() => cargando = true);
    try {
      final data = await supabase
          .from('equipos')
          .select('id, nombre, descripcion, imagen_url, estado')
          .eq('estado', 'mantenimiento')
          .order('id', ascending: true);

      final equiposConDetalle = await Future.wait(
        data.map((equipo) async {
          final reporte = await obtenerUltimoReporte(equipo['id']);
          return {...equipo, ...reporte};
        }),
      );

      if (!mounted) return;
      setState(() {
        equiposEnMantenimiento = equiposConDetalle;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      cargando = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error al cargar equipos: $e")));
    }
  }

  Future<void> marcarComoReparado(int equipoId, String equipoNombre) async {
    try {
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Reparación'),
          content: Text(
              '¿Confirmas que el equipo "$equipoNombre" ha sido reparado y debe volver a "disponible"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Reparado'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      await supabase
          .from('equipos')
          .update({'estado': 'disponible'}).eq('id', equipoId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Equipo "$equipoNombre" marcado como disponible.')),
      );

      await cargarEquiposEnMantenimiento();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error al reparar: $e")));
    }
  }

  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/150';
    if (path.startsWith("http")) return path;

    try {
      return supabase.storage.from('equipos').getPublicUrl(path);
    } catch (_) {
      return 'https://via.placeholder.com/150';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy • HH:mm');

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (equiposEnMantenimiento.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Equipos en Reparación 🛠️"),
          backgroundColor: Colors.red[700],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 16),
              Text(
                "Ningún equipo está en mantenimiento",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text("Todo está en perfecto estado 😊"),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        title: const Text("Equipos en Reparación 🛠️"),
        elevation: 4,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: equiposEnMantenimiento.length,
        itemBuilder: (context, index) {
          final eq = equiposEnMantenimiento[index];
          final img = resolveImageUrl(eq['imagen_url']);
          final fecha = eq['fecha_reporte'] as DateTime?;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.red.shade300, width: 1.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Imagen con mejor estilo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      img,
                      width: 75,
                      height: 75,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.build,
                          size: 65, color: Colors.red.shade400),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eq['nombre'],
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        const SizedBox(height: 4),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "EN MANTENIMIENTO",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text("Último reporte:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700)),
                        Text(eq['ultimo_reporte'],
                            maxLines: 2, overflow: TextOverflow.ellipsis),

                        if (fecha != null)
                          Text(
                            "Reportado por ${eq['recibido_por_nombre']} • ${df.format(fecha)}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // BOTÓN DE REPARACIÓN CORREGIDO: Ahora con texto y icono
                  ElevatedButton.icon(
                    onPressed: () =>
                        marcarComoReparado(eq['id'], eq['nombre']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text(
                      'Reparado',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
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