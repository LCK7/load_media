import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// ===========================================================================
// COMPONENTE REUTILIZABLE: BUSCADOR DE CLIENTE
// ===========================================================================

class ClienteSearchField extends StatefulWidget {
  final Function(String? userId, String? userName) onUserSelected;

  const ClienteSearchField({super.key, required this.onUserSelected});

  @override
  State<ClienteSearchField> createState() => _ClienteSearchFieldState();
}

class _ClienteSearchFieldState extends State<ClienteSearchField> {
  final supabase = Supabase.instance.client;

  String? selectedUserId;
  String? selectedUserName;
  List<Map<String, dynamic>> searchResults = [];

  final TextEditingController _searchController = TextEditingController();

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => searchResults = []);
      return;
    }
    if (query.length < 3) return;

    try {
      final data = await supabase
          .from('usuarios')
          .select('id, nombre, rol')
          .ilike('nombre', '%$query%')
          .eq('rol', 'cliente')
          .limit(5);

      if (mounted) {
        setState(() => searchResults = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (mounted) setState(() => searchResults = []);
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      selectedUserId = user['id'];
      selectedUserName = user['nombre'];
      searchResults = [];
      _searchController.text = user['nombre'];
    });

    widget.onUserSelected(selectedUserId, selectedUserName);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente Seleccionado:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selectedUserId != null
                    ? Colors.blue.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                selectedUserName ?? 'Ninguno',
                style: TextStyle(
                  color: selectedUserId != null
                      ? Colors.blue.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar Cliente (mín. 3 letras)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _searchUsers(v),
              validator: (v) {
                if (selectedUserId == null) {
                  return 'Debe seleccionar un cliente de la lista.';
                }
                return null;
              },
            ),

            if (searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final user = searchResults[index];
                    return ListTile(
                      title: Text(user['nombre']),
                      subtitle: Text("ID: ${user['id'].substring(0, 8)}..."),
                      onTap: () => _selectUser(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ===========================================================================
// PANTALLA PRINCIPAL: REGISTRAR MULTA
// ===========================================================================

class AddMultaScreen extends StatefulWidget {
  const AddMultaScreen({super.key});

  @override
  State<AddMultaScreen> createState() => _AddMultaScreenState();
}

class _AddMultaScreenState extends State<AddMultaScreen> {
  final supabase = Supabase.instance.client;

  final formKey = GlobalKey<FormState>();
  final montoController = TextEditingController();
  final motivoController = TextEditingController();

  String? _selectedUserId;

  int? _prestamoSeleccionadoId;
  List<Map<String, dynamic>> _prestamosDisponibles = [];
  bool _prestamosCargados = false;

  @override
  void initState() {
    super.initState();
    _cargarPrestamosActivos();
  }

  Future<void> _cargarPrestamosActivos() async {
    if (_prestamosCargados) return;

    try {
      final data = await supabase
          .from('prestamos')
          .select('id, reporte_dano, reserva_id(equipo_id(nombre))')
          .not('reporte_dano', 'is', null)
          .order('id', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _prestamosDisponibles = List<Map<String, dynamic>>.from(data);
          _prestamosCargados = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cargando préstamos: $e")),
        );
      }
    }
  }

  Future<void> _agregarMulta() async {
    if (formKey.currentState!.validate() && _selectedUserId != null) {
      try {
        await supabase.from('multas').insert({
          'usuario_id': _selectedUserId!,
          'monto': double.parse(montoController.text),
          'motivo': motivoController.text,
          'prestamo_id': _prestamoSeleccionadoId,
          'pagado': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Multa agregada con éxito.')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al agregar multa: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Multa"),
        backgroundColor: Colors.redAccent,
        elevation: 3,
        shadowColor: Colors.redAccent.withOpacity(0.4),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [

              // --- CLIENTE ---
              ClienteSearchField(
                onUserSelected: (id, name) {
                  setState(() => _selectedUserId = id);
                  formKey.currentState!.validate();
                },
              ),

              const SizedBox(height: 20),

              // --- TARJETA DE MONTO ---
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: montoController,
                        decoration: InputDecoration(
                          labelText: 'Monto de la Multa (S/.)',
                          prefixText: 'S/. ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Ingrese un monto válido.';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: motivoController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Motivo de la Multa',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- TARJETA DE PRÉSTAMOS ---
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Vincular a Préstamo con Daño",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _prestamosCargados
                          ? DropdownButtonFormField<int?>(
                              value: _prestamoSeleccionadoId,
                              decoration: InputDecoration(
                                labelText: 'Seleccionar Préstamo (Opcional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text("No vincular (Multa por mora)"),
                                ),
                                ..._prestamosDisponibles.map((p) {
                                  final name = p['reserva_id']?['equipo_id']?['nombre'] ?? "Equipo";
                                  return DropdownMenuItem(
                                    value: p['id'],
                                    child: Text(
                                      "ID #${p['id']} - $name",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                              ],
                              onChanged: (v) => setState(() => _prestamoSeleccionadoId = v),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- BOTÓN GUARDAR ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _agregarMulta,
                  icon: const Icon(Icons.save),
                  label: const Text("Registrar Multa", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
