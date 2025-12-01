import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogoClienteScreen extends StatefulWidget {
  const CatalogoClienteScreen({super.key});

  @override
  State<CatalogoClienteScreen> createState() => _CatalogoClienteScreenState();
}

class _CatalogoClienteScreenState extends State<CatalogoClienteScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> equipos = [];
  bool cargando = true;
  String busqueda = "";

  @override
  void initState() {
    super.initState();
    cargarEquipos();
  }

  Future<void> cargarEquipos() async {
    try {
      final data = await supabase
          .from('equipos')
          .select()
          .eq('estado', 'disponible');

      setState(() {
        equipos = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error cargando equipos: $e")),
      );
    }
  }

  Future<void> buscarEquipos(String texto) async {
    setState(() => busqueda = texto);

    if (texto.isEmpty) {
      return cargarEquipos();
    }

    try {
      final data = await supabase
          .from('equipos')
          .select()
          .eq('estado', 'disponible')
          .ilike('nombre', '%$texto%');

      setState(() {
        equipos = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error en la búsqueda: $e")),
      );
    }
  }

  Future<void> agregarAlCarrito(int equipoId) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      final existe = await supabase
          .from('carrito')
          .select()
          .eq('user_id', userId)
          .eq('equipo_id', equipoId)
          .maybeSingle();

      if (existe != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Este equipo ya está en tu carrito")),
        );
        return;
      }

      await supabase.from('carrito').insert({
        'user_id': userId,
        'equipo_id': equipoId,
        'cantidad': 1,
        'dias_prestamo': 1,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Añadido al carrito")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al agregar al carrito: $e")),
      );
    }
  }

  String getImagenUrl(dynamic eq) {
    final url = eq['imagen_url']; 

    if (url == null || url.toString().isEmpty) return "";

    if (url.toString().startsWith("http")) return url;

    return supabase.storage.from('equipos').getPublicUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Catálogo de Equipos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: TextField(
              onChanged: buscarEquipos,
              decoration: InputDecoration(
                hintText: "Buscar equipo...",
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),

          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : equipos.isEmpty
                    ? const Center(
                        child: Text(
                          "No hay equipos disponibles",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: equipos.length,
                        itemBuilder: (context, index) {
                          final eq = equipos[index];
                          final imageUrl = getImagenUrl(eq); // Usamos la función corregida

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 7,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                // Imagen
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(18)),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                           // Considerar añadir un loadingBuilder y un errorBuilder
                                        )
                                      : Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.blue.shade100,
                                          child: const Icon(Icons.photo,
                                              size: 40, color: Colors.white),
                                        ),
                                ),

                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          eq['nombre'] ?? 'Sin nombre',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          eq['descripcion'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blue.shade600,
                                              shape:
                                                  RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                            ),
                                            onPressed: () =>
                                                agregarAlCarrito(eq['id']),
                                            child: const Text(
                                              "Reservar",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}