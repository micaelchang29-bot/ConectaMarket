import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/providers_model.dart';
import '../../services/provider_service.dart';
import '../../widgets_global/header_bar.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final Provider? provider; // null = Modo Creación, con data = Modo Edición

  const ProviderDetailsScreen({super.key, this.provider});

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nombreController;
  late TextEditingController _rucController;
  late TextEditingController _telefonoController;

  bool _isEditMode = false;
  String? _rucErrorMessage; // Control dinámico de error para el input RUC

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.provider != null;
    
    // Inicialización pre-cargada para Edición o vacía para Creación
    _nombreController = TextEditingController(text: widget.provider?.nombre ?? '');
    _rucController = TextEditingController(text: widget.provider?.ruc ?? '');
    _telefonoController = TextEditingController(text: widget.provider?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rucController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  /// Ejecuta la persistencia asíncrona hacia el servicio e intercepta errores
  Future<void> _handleSave() async {
    setState(() => _rucErrorMessage = null); // Resetea errores visuales

    if (!_formKey.currentState!.validate()) return;

    final providerId = _isEditMode 
        ? widget.provider!.id 
        : 'PROV-${DateTime.now().millisecondsSinceEpoch}';

    final updatedProvider = Provider(
      id: providerId,
      nombre: _nombreController.text.trim(),
      ruc: _rucController.text.trim().isEmpty ? null : _rucController.text.trim(),
      telefono: _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
    );

    try {
      // Invoca el canal de validaciones SUNAT del servicio antes de insertar a SQLite
      await ProviderService().saveProvider(updatedProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? "Proveedor actualizado" : "Proveedor registrado con éxito"),
            backgroundColor: const Color(0xFF005440),
          ),
        );
        context.pop(); // Regresa al catálogo refrescado
      }
    } catch (e) {
      // Captura el throw Exception de longitud o prefijo incorrecto (10,15,17,20)
      setState(() {
        _rucErrorMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      
      // --- HEADER (TopAppBar Contextual) ---
      appBar: HeaderBarWidget(
        title: _isEditMode ? "Editar Proveedor" : "Nuevo Proveedor",
        onBack: () => context.pop(),
      ),

      // --- MAIN CONTENT (Scrollable Form) ---
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // INPUT: Nombre Comercial
              const Text(
                "Nombre Comercial",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3F4944)),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _nombreController,
                style: const TextStyle(color: Color(0xFF191C1D)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.storefront, color: Color(0xFF6F7A74)),
                  hintText: "Ej. Distribuidora XYZ",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF005440))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "El nombre comercial es obligatorio" : null,
              ),
              const SizedBox(height: 16),

              // INPUT: RUC (Manejo dinámico de estados de error SUNAT)
              Text(
                "RUC (11 dígitos)",
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600, 
                  color: _rucErrorMessage != null ? const Color(0xFFBA1A1A) : const Color(0xFF3F4944),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _rucController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF191C1D)),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined, color: _rucErrorMessage != null ? const Color(0xFFBA1A1A) : const Color(0xFF6F7A74)),
                  suffixIcon: _rucErrorMessage != null ? const Icon(Icons.error, color: Color(0xFFBA1A1A)) : null,
                  filled: true,
                  fillColor: _rucErrorMessage != null ? const Color(0xFFFFDAD6).withValues(alpha: 0.2) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _rucErrorMessage != null ? const Color(0xFFBA1A1A) : const Color(0xFFBEC9C3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _rucErrorMessage != null ? const Color(0xFFBA1A1A) : const Color(0xFF005440), width: 2),
                  ),
                  // Muestra el error de validación retornado por el Service
                  errorText: _rucErrorMessage,
                  errorMaxLines: 2,
                ),
              ),
              if (_rucErrorMessage == null) ...[
                const SizedBox(height: 4),
                const Text(
                  "Debe empezar con 10, 15, 17 o 20",
                  style: TextStyle(fontSize: 12, color: Color(0xFF3F4944)),
                ),
              ],
              const SizedBox(height: 16),

              // INPUT: Teléfono
              const Text(
                "Teléfono",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3F4944)),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF191C1D)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF6F7A74)),
                  hintText: "Ej. 999 888 777",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF005440))),
                ),
              ),
              const SizedBox(height: 24),

              // CARD: Información Contextual de Validación
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE7E8E9)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Color(0xFF005440)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Validación SUNAT",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1D)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "El RUC será validado automáticamente con los registros oficiales al guardar.",
                            style: TextStyle(color: Color(0xFF3F4944), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // --- FIXED FOOTER (Bottom Actions) ---
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFEDEEEF),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Row(
            children: [
              // Botón Cancelar
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF6F7A74)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.pop(),
                  child: const Text("Cancelar", style: TextStyle(color: Color(0xFF005440), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              // Botón Guardar
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005440),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text("Guardar Proveedor", style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _handleSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}