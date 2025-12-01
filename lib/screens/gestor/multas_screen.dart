import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'añadir_multa_screen.dart';

class MultaDisplay {
  final int id;
  final String clienteNombre;
  final double montoTotal;
  final double montoAbonado;
  final double saldoPendiente;
  final String motivo;
  final bool pagado;
  final DateTime createdAt;
  final String? prestamoId;
  final String? reporteDano;
  final String? clienteId;

  MultaDisplay({
    required this.id,
    required this.clienteNombre,
    required this.montoTotal,
    required this.montoAbonado,
    required this.saldoPendiente,
    required this.motivo,
    required this.pagado,
    required this.createdAt,
    this.prestamoId,
    this.reporteDano,
    this.clienteId,
  });

  factory MultaDisplay.fromMap(Map<String, dynamic> data) {
    final usuario = data['usuario_id'];
    final prestamo = data['prestamo_id'];

    final montoTotalValue = data['monto'] is int
        ? (data['monto'] as int).toDouble()
        : (data['monto'] as double);

    final montoAbonadoValue = data['monto_abonado'] is int
        ? (data['monto_abonado'] as int).toDouble()
        : (data['monto_abonado'] as double? ?? 0.0);

    final saldo = montoTotalValue - montoAbonadoValue;

    return MultaDisplay(
      id: data['id'],
      clienteNombre: usuario != null ? usuario['nombre'] : 'Usuario Desconocido',
      clienteId: usuario != null ? usuario['id'] : null,
      montoTotal: montoTotalValue,
      montoAbonado: montoAbonadoValue,
      saldoPendiente: saldo,
      motivo: data['motivo'],
      pagado: data['pagado'] ?? (saldo <= 0),
      createdAt: DateTime.parse(data['created_at']),
      prestamoId: prestamo != null && prestamo['id'] != null
          ? prestamo['id'].toString()
          : null,
      reporteDano: prestamo != null ? prestamo['reporte_dano'] : null,
    );
  }
}

class MultasScreen extends StatefulWidget {
  const MultasScreen({super.key});

  @override
  State<MultasScreen> createState() => _MultasScreenState();
}

class _MultasScreenState extends State<MultasScreen> {
  final supabase = Supabase.instance.client;
  List<MultaDisplay> multas = [];
  bool isLoading = true;
  final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'es_CL', symbol: 'S/', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _cargarMultas();
  }

  Future<void> _cargarMultas() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await supabase
          .from('multas')
          .select('*, usuario_id(nombre, id), prestamo_id(id, reporte_dano)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          multas = data.map((map) => MultaDisplay.fromMap(map)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar multas: $e')),
        );
      }
    }
  }

  void _navegarAcrearMulta() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddMultaScreen()),
    );

    if (result == true) {
      _cargarMultas();
    }
  }

  Future<void> _mostrarModalAbono(MultaDisplay multa) async {
    final formKey = GlobalKey<FormState>();
    final abonoController = TextEditingController();
    final double maxAbono = multa.saldoPendiente;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Registrar Abono',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo Pendiente:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  currencyFormat.format(maxAbono),
                  style: const TextStyle(
                      color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: abonoController,
                  decoration: InputDecoration(
                    labelText: 'Monto a Abonar',
                    prefixText: 'S/ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final abono = double.tryParse(v ?? '');
                    if (abono == null || abono <= 0) {
                      return 'Ingrese un monto válido';
                    }
                    if (abono > maxAbono) {
                      return 'Excede el saldo pendiente';
                    }
                    return null;
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _ejecutarAbono(multa, double.parse(abonoController.text));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent),
              child: const Text("Confirmar"),
            )
          ],
        );
      },
    );
  }

  Future<void> _ejecutarAbono(MultaDisplay multa, double abono) async {
    final nuevoMontoAbonado = multa.montoAbonado + abono;
    final nuevoSaldo = multa.montoTotal - nuevoMontoAbonado;
    final totalmentePagado = nuevoSaldo <= 0;

    try {
      await supabase.from('multas').update({
        'monto_abonado': nuevoMontoAbonado,
        'pagado': totalmentePagado,
      }).eq('id', multa.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalmentePagado
                  ? 'Multa pagada totalmente'
                  : 'Abono registrado correctamente',
            ),
          ),
        );
        _cargarMultas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Multas'),
        backgroundColor: Colors.redAccent,
        elevation: 4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : multas.isEmpty
              ? const Center(
                  child: Text('No hay multas registradas.',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: multas.length,
                  itemBuilder: (context, i) {
                    final m = multas[i];

                    final Color statusColor = m.pagado
                        ? Colors.green.shade600
                        : m.montoAbonado > 0
                            ? Colors.orange.shade700
                            : Colors.red.shade700;

                    final String statusText = m.pagado
                        ? "Pagada"
                        : m.montoAbonado > 0
                            ? "Abono Parcial"
                            : "Pendiente";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: statusColor,
                                  child: Icon(
                                    m.pagado ? Icons.check : Icons.warning,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    m.clienteNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),

                            const SizedBox(height: 10),

                            Text("Motivo: ${m.motivo}",
                                style: const TextStyle(fontSize: 14)),

                            const SizedBox(height: 6),

                            Text(
                              "Total: ${currencyFormat.format(m.montoTotal)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text("Abonado: ${currencyFormat.format(m.montoAbonado)}"),
                            Text("Saldo: ${currencyFormat.format(m.saldoPendiente)}",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: m.pagado ? Colors.green : Colors.red)),

                            if (m.reporteDano != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Reporte daño: ${m.reporteDano}",
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],

                            const SizedBox(height: 12),

                            Align(
                              alignment: Alignment.centerRight,
                              child: m.pagado
                                  ? const Text(
                                      "Pagado",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _mostrarModalAbono(m),
                                      icon: const Icon(Icons.add_task),
                                      label: const Text("Abonar"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                      ),
                                    ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarAcrearMulta,
        label: const Text('Añadir Multa'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
