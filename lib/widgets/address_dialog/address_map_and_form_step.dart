import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Step 2: Mapa + Formulário (unificado)
/// Mostra o mapa com o formulário sobreposto
class AddressMapAndFormStep extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController referenceController;
  final TextEditingController neighborhoodController;
  final String favoriteLabel;
  final Function(String) onFavoriteLabelChanged;

  const AddressMapAndFormStep({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.onSave,
    required this.onBack,
    required this.numberController,
    required this.complementController,
    required this.referenceController,
    required this.neighborhoodController,
    required this.favoriteLabel,
    required this.onFavoriteLabelChanged,
  });

  @override
  State<AddressMapAndFormStep> createState() => _AddressMapAndFormStepState();
}

class _AddressMapAndFormStepState extends State<AddressMapAndFormStep> {
  // Mutable location and address fields
  late double _latitude;
  late double _longitude;
  late String _street;
  late String _neighborhood;
  late String _city;
  late String _state;

  // Controller for street field (read-only)
  late TextEditingController _streetController;

  // Flag to show neighborhood field when missing
  bool get _showNeighborhoodField => _neighborhood.isEmpty;

  // UI state – whether the form is visible
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    // Initialise mutable state from widget parameters
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    _street = widget.street;
    _neighborhood = widget.neighborhood;
    _city = widget.city;
    _state = widget.state;
    _streetController = TextEditingController(text: _street);
  }

  @override
  void dispose() {
    _streetController.dispose();
    super.dispose();
  }

  // Placeholder reverse‑geocode – in a real app you'd call an API.
  void _updateAddressFromCoordinates() {
    // Mock implementation: generate fake address components based on coordinates.
    setState(() {
      _street = "Rua ${_latitude.toStringAsFixed(3)}";
      _neighborhood = "Bairro ${_longitude.toStringAsFixed(3)}";
      _city = "Cidade Exemplo";
      _state = "Estado Exemplo";
      widget.neighborhoodController.text = _neighborhood;
      _streetController.text = _street;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final fullAddress = "$_neighborhood, $_city - $_state";

    return Stack(
      key: const ValueKey('mapAndForm'),
      children: [
        // ===== MAPA (FUNDO) =====
        if (mapboxToken.isNotEmpty)
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(_latitude, _longitude),
              initialZoom: 16.0,
              interactionOptions: InteractionOptions(
                // Bloqueia interação quando o formulário está aberto
                flags: _showForm ? InteractiveFlag.none : InteractiveFlag.all,
              ),
              // Tap on the map moves the pin and updates the address.
              onTap: (tapPosition, point) {
                setState(() {
                  _latitude = point.latitude;
                  _longitude = point.longitude;
                });
                _updateAddressFromCoordinates();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
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

        // ===== HEADER =====
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: _buildHeader(context),
        ),

        // ===== PIN + LABEL (só aparece quando formulário está fechado) =====
        if (!_showForm)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PinLabel(),
                SizedBox(height: 4),
                _RedPin(),
              ],
            ),
          ),

        // ===== BOTÃO CONFIRMAR (só aparece quando formulário está fechado) =====
        if (!_showForm)
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: _buildConfirmButton(context),
          ),

        // ===== FORMULÁRIO (sobe sobre o mapa) =====
        if (_showForm)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFormContent(fullAddress),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (_showForm) {
                setState(() => _showForm = false);
              } else {
                widget.onBack();
              }
            },
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
          const Text(
            'ENDEREÇO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(width: 48), // Espaço para balancear
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed: () {
        setState(() => _showForm = true);
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Confirmar localização',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(String fullAddress) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Powered by Google
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
          'https://www.google.com/images/poweredby_transparent/poweredby_FFFFFF/14px/poweredby_google_on_white_hdpi.png',
          height: 14,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildAddressInfo(String fullAddress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _street,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bairro e Rua (apenas se não houver bairro) - na mesma linha
        if (_showNeighborhoodField) ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFormField(
                  controller: widget.neighborhoodController,
                  label: 'Bairro',
                  hintText: 'Bairro',
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildFormField(
                  controller: _streetController,
                  label: 'Rua',
                  hintText: '',
                  isReadOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
                isRequired: true, // ✅ Campo obrigatório
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
    bool isRequired = false,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F3E3E),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hintText,
            filled: isReadOnly,
            fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
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
        Expanded(
          child: _buildFavoriteButton(
            icon: Icons.home,
            label: 'Casa',
            isSelected: widget.favoriteLabel == 'Casa',
            onTap: () => widget.onFavoriteLabelChanged(
                widget.favoriteLabel == 'Casa' ? '' : 'Casa'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFavoriteButton(
            icon: Icons.work,
            label: 'Trabalho',
            isSelected: widget.favoriteLabel == 'Trabalho',
            onTap: () => widget.onFavoriteLabelChanged(
                widget.favoriteLabel == 'Trabalho' ? '' : 'Trabalho'),
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
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
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
}

// Widget do Pin VERMELHO
class _RedPin extends StatelessWidget {
  const _RedPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      color: Colors.red,
      size: 32,
    );
  }
}

// Widget do Label acima do pin
class _PinLabel extends StatelessWidget {
  const _PinLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Você está aqui?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Ajuste a localização',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
