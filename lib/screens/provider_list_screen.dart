import 'package:flutter/material.dart';
import '../../models/providers_model.dart';
import '../../services/provider_service.dart';
import 'provider_details_screen.dart'; // Tu pantalla completa de detalles
import '../../widgets_global/header_bar.dart';

class ProviderListScreen extends StatefulWidget {
  const ProviderListScreen({super.key});

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Despliega una alerta nativa de confirmación antes de eliminar de SQLite
  Future<void> _confirmDelete(BuildContext context, Provider provider) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Proveedor"),
        content: Text("¿Está seguro de que desea eliminar a ${provider.nombre}? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ProviderService().removeProvider(provider.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Proveedor eliminado exitosamente"), backgroundColor: Color(0xFF005440)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar: $e"), backgroundColor: const Color(0xFFBA1A1A)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // --- TOP APP BAR ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<List<Provider>>(
          stream: ProviderService().providerStream,
          initialData: ProviderService().cachedProviders,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return HeaderBarWidget(
              title: "Mis Proveedores",
              badgeCount: count,
              showBackButton: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync, color: Color(0xFF3F4944)),
                  onPressed: () async {
                    await ProviderService().refreshProviders();
                  },
                ),
              ],
            );
          },
        ),
      ),
      
      // --- MAIN CONTENT ---
      body: SafeArea(
        child: Column(
          children: [
            // BARRA DE BÚSQUEDA REACTIVA EN RAM
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6F7A74)),
                  hintText: "Buscar por nombre o RUC...",
                  filled: true,
                  fillColor: const Color(0xFFFFFFFF),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFBEC9C3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF005440), width: 2),
                  ),
                ),
              ),
            ),

            // LISTA DE PROVEEDORES (Flujo continuo del Stream)
            Expanded(
              child: StreamBuilder<List<Provider>>(
                stream: ProviderService().providerStream,
                // REQUERIMIENTO VISUAL DE TESIS: initialData jala de la RAM al instante (0ms)
                initialData: ProviderService().cachedProviders,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && 
                     (snapshot.data == null || snapshot.data!.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Aplicamos el filtrado reactivo veloz directo en el hilo de Dart
                  final filteredList = snapshot.data!.where((p) {
                    return p.nombre.toLowerCase().contains(_searchQuery) ||
                           (p.ruc?.contains(_searchQuery) ?? false);
                  }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(
                      child: Text(
                        "No se encontraron proveedores",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final provider = filteredList[index];

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFBEC9C3), width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProviderDetailsScreen(provider: provider),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Datos del Proveedor
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              provider.nombre,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF191C1D),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Badge dinámico para emular el del prototipo si lo deseas
                                          if (index == 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFDAD4E),
                                                borderRadius: BorderRadius.circular(9999),
                                              ),
                                              child: const Text(
                                                "Socio Estratégico",
                                                style: TextStyle(fontSize: 10, color: Color(0xFF2B1700), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            "RUC: ${provider.ruc ?? 'No registrado'}",
                                            style: const TextStyle(color: Color(0xFF3F4944), fontSize: 14),
                                          ),
                                          Text(
                                            "Tel: ${provider.telefono ?? 'No registrado'}",
                                            style: const TextStyle(color: Color(0xFF3F4944), fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Botones de Acción (Modo Móvil Ergonómico)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF6F7A74)),
                                      onPressed: () {
                                        // Navegación declarativa limpia pasándole la data al constructor
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProviderDetailsScreen(provider: provider),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                                      onPressed: () => _confirmDelete(context, provider),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // --- FLOATING ACTION BUTTON (Añadir Proveedor) ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F6E56),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          // Navegación en Modo Creación (Pasando null)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProviderDetailsScreen(provider: null),
            ),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}