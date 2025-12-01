import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Prestamo {
  final int id;
  final String equipoNombre;
  final String clienteNombre;
  final String entregadoPorNombre;
  final String recibidoPorNombre;
  final DateTime? fechaEntrega;
  final DateTime? fechaDevolucion;
  final String? reporteDano;
  final String estadoReserva;
  final String fotoEntregaUrl;
  final String fotoDevolucionUrl;

  Prestamo({
    required this.id,
    required this.equipoNombre,
    required this.clienteNombre,
    required this.entregadoPorNombre,
    required this.recibidoPorNombre,
    this.fechaEntrega,
    this.fechaDevolucion,
    this.reporteDano,
    required this.estadoReserva,
    required this.fotoEntregaUrl,
    required this.fotoDevolucionUrl,
  });
}

class HistorialPrestamosScreen extends StatefulWidget {
  const HistorialPrestamosScreen({super.key});

  @override
  State<HistorialPrestamosScreen> createState() =>
      _HistorialPrestamosScreenState();
}

class _HistorialPrestamosScreenState extends State<HistorialPrestamosScreen> {
  final supabase = Supabase.instance.client;
  List<Prestamo> historialCompleto = [];
  List<Prestamo> historialFiltrado = [];
  bool cargando = true;
  DateTime? fechaInicioFiltro;
  DateTime? fechaFinFiltro;

  late PrestamoDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    setState(() => cargando = true);
    try {
      final data = await supabase
          .from('prestamos')
          .select('''
            id,
            fecha_entrega,
            fecha_devolucion,
            reporte_dano,
            foto_entrega_url,
            foto_devolucion_url,
            entregado_por(nombre),
            recibido_por(nombre),
            reservas!inner(
              estado,
              equipos(nombre),
              usuarios(nombre)
            )
          ''')
          .order('fecha_entrega', ascending: false);

      final List<Prestamo> prestamos = data.map((item) {
        final reserva = item['reservas'] as Map<String, dynamic>? ?? {};
        final equipo = reserva['equipos'] as Map<String, dynamic>? ?? {};
        final cliente = reserva['usuarios'] as Map<String, dynamic>? ?? {};
        final entregadoPor = item['entregado_por'] as Map<String, dynamic>? ?? {};
        final recibidoPor = item['recibido_por'] as Map<String, dynamic>? ?? {};

        return Prestamo(
          id: item['id'],
          equipoNombre: equipo['nombre'] ?? 'N/A',
          clienteNombre: cliente['nombre'] ?? 'N/A',
          entregadoPorNombre: entregadoPor['nombre'] ?? 'N/A',
          recibidoPorNombre: recibidoPor['nombre'] ?? 'N/A',
          fechaEntrega: item['fecha_entrega'] != null
              ? DateTime.parse(item['fecha_entrega']).toLocal()
              : null,
          fechaDevolucion: item['fecha_devolucion'] != null
              ? DateTime.parse(item['fecha_devolucion']).toLocal()
              : null,
          reporteDano: item['reporte_dano'],
          estadoReserva: reserva['estado'] ?? 'N/A',
          fotoEntregaUrl: item['foto_entrega_url'] ?? '',
          fotoDevolucionUrl: item['foto_devolucion_url'] ?? '',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        historialCompleto = prestamos;
        historialFiltrado = prestamos;
        _dataSource = PrestamoDataSource(historialFiltrado, context);
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el historial: $e')),
      );
      setState(() => cargando = false);
    }
  }

  void aplicarFiltro() {
    setState(() {
      historialFiltrado = historialCompleto.where((p) {
        if (p.fechaEntrega == null) return false;

        final fecha = p.fechaEntrega!;

        bool okInicio = fechaInicioFiltro == null ||
            fecha.isAfter(fechaInicioFiltro!.subtract(const Duration(milliseconds: 1)));

        bool okFin = fechaFinFiltro == null ||
            fecha.isBefore(
                fechaFinFiltro!.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));

        return okInicio && okFin;
      }).toList();

      _dataSource = PrestamoDataSource(historialFiltrado, context);
    });
  }

  Future<void> _seleccionarFecha(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart ? 'Fecha de inicio' : 'Fecha de fin',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          fechaInicioFiltro = picked;
        } else {
          fechaFinFiltro = picked;
        }
        aplicarFiltro();
      });
    }
  }

  void limpiarFiltro() {
    setState(() {
      fechaInicioFiltro = null;
      fechaFinFiltro = null;
      historialFiltrado = historialCompleto;
      _dataSource = PrestamoDataSource(historialFiltrado, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text(
          "Historial de Préstamos 📑",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.indigo.shade600,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ⭐ Filtro dentro de tarjeta
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Filtrar por Fecha de Entrega",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _seleccionarFecha(true),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    fechaInicioFiltro == null
                                        ? "Inicio"
                                        : DateFormat('dd/MMM/yy')
                                            .format(fechaInicioFiltro!),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _seleccionarFecha(false),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    fechaFinFiltro == null
                                        ? "Fin"
                                        : DateFormat('dd/MMM/yy')
                                            .format(fechaFinFiltro!),
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: limpiarFiltro,
                                icon: const Icon(Icons.clear),
                                tooltip: "Limpiar",
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ⭐ Tabla estilizada
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black12,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: PaginatedDataTable(
                      columnSpacing: 20,
                      header: Text(
                        "Total Préstamos: ${historialFiltrado.length}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text("ID")),
                        DataColumn(label: Text("Equipo")),
                        DataColumn(label: Text("Cliente")),
                        DataColumn(label: Text("Entregado")),
                        DataColumn(label: Text("Recibido")),
                        DataColumn(label: Text("Entrega")),
                        DataColumn(label: Text("Devolución")),
                        DataColumn(label: Text("Estado")),
                        DataColumn(label: Text("Daño")),
                      ],
                      source: _dataSource,
                      showCheckboxColumn: false,
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

class PrestamoDataSource extends DataTableSource {
  final List<Prestamo> data;
  final BuildContext context;
  final df = DateFormat('dd-MMM-yy HH:mm');

  PrestamoDataSource(this.data, this.context);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final p = data[index];

    Color? rowColor;
    if (p.reporteDano != null && p.reporteDano!.isNotEmpty) {
      rowColor = Colors.red.shade50;
    }

    return DataRow(
      color: MaterialStateProperty.all(rowColor),
      cells: [
        DataCell(Text(p.id.toString())),
        DataCell(Text(p.equipoNombre)),
        DataCell(Text(p.clienteNombre)),
        DataCell(Text(p.entregadoPorNombre)),
        DataCell(Text(p.recibidoPorNombre)),
        DataCell(Text(p.fechaEntrega != null ? df.format(p.fechaEntrega!) : 'N/A')),
        DataCell(Text(
            p.fechaDevolucion != null ? df.format(p.fechaDevolucion!) : 'PEND.')),
        DataCell(
          Text(
            p.estadoReserva.toUpperCase(),
            style: TextStyle(
              color: p.estadoReserva == "finalizada"
                  ? Colors.green.shade800
                  : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          InkWell(
            onTap: p.reporteDano != null && p.reporteDano!.isNotEmpty
                ? () => _mostrarDetalle(context, p.reporteDano!)
                : null,
            child: Text(
              p.reporteDano != null && p.reporteDano!.isNotEmpty
                  ? "SÍ (ver)"
                  : "NO",
              style: TextStyle(
                color: p.reporteDano != null && p.reporteDano!.isNotEmpty
                    ? Colors.red.shade800
                    : Colors.green.shade800,
                decoration: p.reporteDano != null && p.reporteDano!.isNotEmpty
                    ? TextDecoration.underline
                    : TextDecoration.none,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarDetalle(BuildContext context, String reporte) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reporte de Daño"),
        content: Text(reporte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          )
        ],
      ),
    );
  }

  @override
  int get rowCount => data.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
