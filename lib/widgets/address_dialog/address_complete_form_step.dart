import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Step 3: Formulário final para completar detalhes do endereço
class AddressCompleteFormStep extends StatefulWidget {
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController referenceController;
  final String favoriteLabel;
  final Function(String) onFavoriteLabelChanged;

  const AddressCompleteFormStep({
    super.key,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.onSave,
    required this.onBack,
    required this.numberController,
    required this.complementController,
    required this.referenceController,
    required this.favoriteLabel,
    required this.onFavoriteLabelChanged,
  });

  @override
  State<AddressCompleteFormStep> createState() => _AddressCompleteFormStepState();
}

class _AddressCompleteFormStepState extends State<AddressCompleteFormStep> {
  @override
  Widget build(BuildContext context) {
    final fullAddress = '${widget.neighborhood}, ${widget.city} - ${widget.state}';

    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          _buildMap(),

          // Conteúdo principal
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFormContent(fullAddress),
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

    return Stack(
      children: [
        // Mapa real usando Flutter Map
        if (mapboxToken.isNotEmpty)
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(-19.880714, -43.866214), // Coordenadas do exemplo
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20),

            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(String fullAddress) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
            // Powered by
            _buildPoweredBy(),
            const SizedBox(height: 16),

            // Informações do endereço
            _buildAddressInfo(fullAddress),
            const SizedBox(height: 24),

            // Formulário
            _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildPoweredBy() {
    return Center(
      child: SizedBox(
        width: 96,
        height: 12,
        child: Image.network(
          'data:image/png;base64,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',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildAddressInfo(String fullAddress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.street,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fullAddress,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número e Complemento
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildFormField(
                controller: widget.numberController,
                label: 'Número',
                hintText: '',
                isNumber: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormField(
                    controller: widget.complementController,
                    label: 'Complemento',
                    hintText: 'Complemento',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apartamento/Bloco/Casa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ponto de referência
        _buildFormField(
          controller: widget.referenceController,
          label: 'Ponto de referência',
          hintText: 'Ponto de referência',
        ),
        const SizedBox(height: 24),

        // Favoritar como
        const Text(
          'Favoritar como',
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
            onPressed: widget.onSave,
            child: const Text(
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
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hintText,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildFavoriteButton(
            icon: Icons.home,
            label: 'Casa',
            isSelected: widget.favoriteLabel == 'Casa',
            onTap: () => widget.onFavoriteLabelChanged(
                widget.favoriteLabel == 'Casa' ? '' : 'Casa'
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFavoriteButton(
            icon: Icons.work,
            label: 'Trabalho',
            isSelected: widget.favoriteLabel == 'Trabalho',
            onTap: () => widget.onFavoriteLabelChanged(
                widget.favoriteLabel == 'Trabalho' ? '' : 'Trabalho'
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
      color: Colors.white54,
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
              Icons.arrow_back_ios_rounded,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 8),

          // Título centralizado
          Expanded(
            child: Center(
              child: Text(
                'ENDEREÇO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F3E3E),
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



