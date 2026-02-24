import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Step 3: Formulário final para completar detalhes do endereço
/// Estilo Menuhub: mostra endereço completo no header, com opção de editar
class AddressCompleteFormStep extends StatefulWidget {
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final double? latitude;
  final double? longitude;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController referenceController;
  final TextEditingController? streetController;
  final TextEditingController? neighborhoodController;
  final String favoriteLabel;
  final Function(String) onFavoriteLabelChanged;
  final bool isSaving;

  const AddressCompleteFormStep({
    super.key,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    this.latitude,
    this.longitude,
    required this.onSave,
    required this.onBack,
    required this.numberController,
    required this.complementController,
    required this.referenceController,
    this.streetController,
    this.neighborhoodController,
    required this.favoriteLabel,
    required this.onFavoriteLabelChanged,
    this.isSaving = false,
  });

  @override
  State<AddressCompleteFormStep> createState() => _AddressCompleteFormStepState();
}

class _AddressCompleteFormStepState extends State<AddressCompleteFormStep> {
  // Estado de edição - começa true se bairro estiver vazio
  late bool _isEditing;
  
  // Checkboxes
  bool _noNumber = false;
  bool _noComplement = false;
  
  // Verifica se bairro está vazio
  bool get _neighborhoodEmpty => 
      widget.neighborhood.isEmpty && 
      (widget.neighborhoodController?.text.trim().isEmpty ?? true);

  @override
  void initState() {
    super.initState();
    // Se bairro estiver vazio, começa em modo edição
    _isEditing = _neighborhoodEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final streetDisplay = widget.streetController?.text.isNotEmpty == true
        ? widget.streetController!.text
        : widget.street;
    final numberDisplay = widget.numberController.text.isNotEmpty
        ? widget.numberController.text
        : 'S/N';
    final neighborhoodDisplay = widget.neighborhoodController?.text.isNotEmpty == true
        ? widget.neighborhoodController!.text
        : widget.neighborhood;
    
    final addressTitle = '$streetDisplay, $numberDisplay';
    final addressSubtitle = '$neighborhoodDisplay, ${widget.city} - ${widget.state}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Mapa
          _buildMap(),

          // Conteúdo principal
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFormContent(addressTitle, addressSubtitle),
          ),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // Mapa real usando Flutter Map
          if (mapboxToken.isNotEmpty)
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  widget.latitude ?? -19.880714,
                  widget.longitude ?? -43.866214,
                ),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Desabilita interação no mini mapa
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  userAgentPackageName: 'com.menuhub.totem',
                  tileSize: 512,
                  zoomOffset: -1,
                ),
              ],
            )
          else
            Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Configure MAPBOX_ACCESS_TOKEN para ver o mapa',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Pin no centro do mapa
          const Center(
            child: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
          
          // Botão "Ajustar marcador"
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Ajustar marcador',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(String addressTitle, String addressSubtitle) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do endereço com botão de editar
            _buildAddressHeader(addressTitle, addressSubtitle),
            const SizedBox(height: 24),

            // Formulário
            _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isNotEmpty ? title : 'Endereço não encontrado',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        // Botão de editar
        IconButton(
          onPressed: () {
            setState(() => _isEditing = !_isEditing);
          },
          icon: Icon(
            _isEditing ? Icons.check : Icons.edit_outlined,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modo edição: mostra todos os campos
        if (_isEditing) ...[
          // Rua
          if (widget.streetController != null)
            _buildFormField(
              controller: widget.streetController!,
              label: 'Rua *',
              hintText: 'Nome da rua',
            ),
          if (widget.streetController != null)
            const SizedBox(height: 16),
          
          // Bairro
          if (widget.neighborhoodController != null)
            _buildFormField(
              controller: widget.neighborhoodController!,
              label: 'Bairro *',
              hintText: 'Nome do bairro',
            ),
          if (widget.neighborhoodController != null)
            const SizedBox(height: 16),
          
          // Número
          _buildFormField(
            controller: widget.numberController,
            label: 'Número *',
            hintText: 'Nº',
            isNumber: true,
            enabled: !_noNumber,
          ),
          // Checkbox "Endereço sem número"
          CheckboxListTile(
            value: _noNumber,
            onChanged: (value) {
              setState(() {
                _noNumber = value ?? false;
                if (_noNumber) {
                  widget.numberController.text = 'S/N';
                } else {
                  widget.numberController.clear();
                }
              });
            },
            title: Text(
              'Endereço sem número',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 8),
        ],

        // Complemento (sempre visível)
        _buildFormField(
          controller: widget.complementController,
          label: 'Complemento *',
          hintText: 'Apto, Bloco, Casa...',
          enabled: !_noComplement,
        ),
        // Checkbox "Endereço sem complemento"
        CheckboxListTile(
          value: _noComplement,
          onChanged: (value) {
            setState(() {
              _noComplement = value ?? false;
              if (_noComplement) {
                widget.complementController.clear();
              }
            });
          },
          title: Text(
            'Endereço sem complemento',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 16),

        // Ponto de referência (sempre visível)
        _buildFormField(
          controller: widget.referenceController,
          label: 'Ponto de referência (opcional)',
          hintText: 'Próximo ao mercado, em frente à praça...',
        ),
        const SizedBox(height: 24),

        // Favoritar como
        const Text(
          'Favoritar endereço',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 12),
        _buildFavoriteButtons(),
        const SizedBox(height: 24),

        // Botão salvar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            onPressed: widget.isSaving ? null : widget.onSave,
            child: widget.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Salvar endereço',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isNumber = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButtons() {
    return Row(
      children: [
        _buildFavoriteButton(
          icon: Icons.home,
          label: 'Casa',
          isSelected: widget.favoriteLabel == 'Casa',
          onTap: () => widget.onFavoriteLabelChanged(
              widget.favoriteLabel == 'Casa' ? '' : 'Casa'),
        ),
        const SizedBox(width: 12),
        _buildFavoriteButton(
          icon: Icons.work,
          label: 'Trabalho',
          isSelected: widget.favoriteLabel == 'Trabalho',
          onTap: () => widget.onFavoriteLabelChanged(
              widget.favoriteLabel == 'Trabalho' ? '' : 'Trabalho'),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor.withAlpha(25) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF3F3E3E),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF3F3E3E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withAlpha(230),
      child: Row(
        children: [
          // Botão voltar
          IconButton(
            onPressed: widget.onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              Icons.arrow_back,
              size: 24,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 8),

          // Título centralizado
          const Expanded(
            child: Center(
              child: Text(
                'ENDEREÇO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
            ),
          ),

          // Espaço para balancear
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
