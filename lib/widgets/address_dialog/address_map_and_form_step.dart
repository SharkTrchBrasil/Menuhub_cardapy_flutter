import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:totem/services/reverse_geocoding_service.dart';

/// Step 2: Mapa + Formulário (unificado)
/// Mostra o mapa com o formulário sobreposto
/// ✅ ENTERPRISE VERSION - Com correções de bugs críticos
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
  final TextEditingController streetController;
  final String favoriteLabel;
  final Function(String) onFavoriteLabelChanged;
  // ✅ NOVO: Callback para atualizar coordenadas no pai
  final Function(double lat, double lon)? onCoordinatesChanged;
  // ✅ NOVO: Se true, inicia diretamente no formulário (para edição)
  final bool startWithForm;

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
    required this.streetController,
    required this.favoriteLabel,
    required this.onFavoriteLabelChanged,
    this.onCoordinatesChanged,
    this.startWithForm = false, // ✅ Por padrão, começa no mapa
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

  // ✅ CORREÇÃO: Removido o sumiço automático dos campos ao digitar ou trocar o favorito.
  // Uma vez que o formulário é exibido, mantemos os campos de Bairro e Rua visíveis
  // para conferência e edição, pois o geocoding nem sempre é preciso.
  bool get _showManualAddressFields => true;

  // UI state – whether the form is visible
  bool _showForm = false;

  // Loading state for reverse geocoding
  bool _isLoadingAddress = false;

  // ✅ CORREÇÃO BUG #1: Error state para retry
  bool _hasError = false;
  String _errorMessage = '';

  // ✅ CORREÇÃO BUG #1: Race condition - cancelamento de requisições
  int _requestCounter = 0;

  // ✅ CORREÇÃO BUG #4: Debounce timer
  Timer? _debounceTimer;

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

    // Inicializa controllers com valores iniciais
    widget.streetController.text = _street;
    widget.neighborhoodController.text = _neighborhood;

    print('🗺️ [MAPBOX] Inicializando mapa em: $_latitude, $_longitude');
    print(
      '🗺️ [MAPBOX] Token presente: ${dotenv.env['MAPBOX_ACCESS_TOKEN']?.isNotEmpty ?? false}',
    );

    // ✅ Se startWithForm = true, abre direto no formulário
    if (widget.startWithForm) {
      _showForm = true;
    }
  }

  @override
  void dispose() {
    // ✅ CORREÇÃO BUG #4: Cancela timer de debounce
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ✅ CORREÇÃO BUG #1 e #4: Reverse geocoding com cancelamento e debounce
  void _onMapTapped(double lat, double lon) {
    // ✅ CORREÇÃO BUG #5: Não permite mover pin se formulário está aberto
    if (_showForm) return;

    // Atualiza coordenadas imediatamente para feedback visual
    setState(() {
      _latitude = lat;
      _longitude = lon;
    });

    // ✅ Notifica o pai sobre mudança de coordenadas
    widget.onCoordinatesChanged?.call(lat, lon);

    // ✅ CORREÇÃO BUG #4: Cancela timer anterior e cria novo (debounce)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateAddressFromCoordinates(lat, lon);
    });
  }

  // ✅ CORREÇÃO BUG #1: Reverse geocoding com cancelamento de requisições
  Future<void> _updateAddressFromCoordinates(double lat, double lon) async {
    // Incrementa contador de requisições
    final currentRequest = ++_requestCounter;

    print('🔍 [$currentRequest] Iniciando reverse geocoding para: $lat, $lon');

    if (!mounted) return;

    setState(() {
      _isLoadingAddress = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final addressData =
          await ReverseGeocodingService.getAddressFromCoordinates(
            latitude: lat,
            longitude: lon,
          ).timeout(
            const Duration(seconds: 15), // ✅ CORREÇÃO BUG #6: Timeout explícito
            onTimeout: () {
              throw TimeoutException('Tempo esgotado ao buscar endereço');
            },
          );

      // ✅ CORREÇÃO BUG #1: Verifica se esta ainda é a requisição mais recente
      if (!mounted || currentRequest != _requestCounter) {
        print(
          '⚠️ [$currentRequest] Requisição cancelada (nova requisição em andamento)',
        );
        return;
      }

      if (addressData != null) {
        // ✅ CORREÇÃO BUG #11: Usa controllers como fonte única de verdade
        setState(() {
          _street = addressData['street'] ?? '';
          _neighborhood = addressData['neighborhood'] ?? '';
          _city = addressData['city'] ?? '';
          _state = addressData['state'] ?? '';

          // Atualiza os controllers
          widget.neighborhoodController.text = _neighborhood;
          widget.streetController.text = _street;
          _isLoadingAddress = false;
        });

        print('✅ [$currentRequest] Endereço atualizado:');
        print('   Rua: $_street');
        print('   Bairro: $_neighborhood');
        print('   Cidade: $_city');
        print('   Estado: $_state');
      } else {
        print('⚠️ [$currentRequest] Nenhum endereço encontrado');
        if (mounted) {
          setState(() {
            _isLoadingAddress = false;
            _hasError = true;
            _errorMessage = 'Endereço não encontrado';
          });
        }
      }
    } on TimeoutException catch (e) {
      print('❌ [$currentRequest] Timeout: $e');
      if (mounted && currentRequest == _requestCounter) {
        setState(() {
          _isLoadingAddress = false;
          _hasError = true;
          _errorMessage = 'Tempo esgotado. Toque para tentar novamente.';
        });
      }
    } catch (e) {
      print('❌ [$currentRequest] Erro ao buscar endereço: $e');
      if (mounted && currentRequest == _requestCounter) {
        setState(() {
          _isLoadingAddress = false;
          _hasError = true;
          _errorMessage =
              'Erro ao buscar endereço. Toque para tentar novamente.';
        });
      }
    }
  }

  // ✅ CORREÇÃO BUG #10: Retry em caso de erro
  void _retryGeocoding() {
    _updateAddressFromCoordinates(_latitude, _longitude);
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
            key: ValueKey(
              'map_${_latitude}_$_longitude',
            ), // ✅ Força rebuild ao mudar
            options: MapOptions(
              initialCenter: LatLng(_latitude, _longitude),
              initialZoom: 16.0,
              interactionOptions: InteractionOptions(
                // Bloqueia interação quando o formulário está aberto
                flags: _showForm ? InteractiveFlag.none : InteractiveFlag.all,
              ),
              // ✅ CORREÇÃO: Usa método com debounce e cancelamento
              onTap: (tapPosition, point) {
                _onMapTapped(point.latitude, point.longitude);
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PinLabel(
                  isLoading: _isLoadingAddress,
                  hasError: _hasError,
                  errorMessage: _errorMessage,
                  onRetry: _retryGeocoding,
                ),
                const SizedBox(height: 4),
                const _RedPin(),
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
    // ✅ Em modo edição (startWithForm), não mostra seta de voltar
    final showBackButton = !widget.startWithForm || !_showForm;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ Oculta seta de voltar em modo edição
          if (showBackButton)
            IconButton(
              onPressed: () {
                if (_showForm && !widget.startWithForm) {
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
            )
          else
            const SizedBox(
              width: 48,
            ), // Espaço para balancear quando não tem seta
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
    // ✅ CORREÇÃO BUG #9: Desabilita botão durante loading
    final isDisabled = _isLoadingAddress || _hasError;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isDisabled ? Colors.grey.shade400 : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed:
          isDisabled
              ? null
              : () {
                setState(() => _showForm = true);
              },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoadingAddress) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            _isLoadingAddress
                ? 'Buscando endereço...'
                : _hasError
                ? 'Erro ao buscar endereço'
                : 'Confirmar localização',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      decoration: const BoxDecoration(color: Colors.white),
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
          _street.isNotEmpty ? _street : 'Endereço não encontrado',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3F3E3E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fullAddress,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bairro e Rua - na mesma linha
        if (_showManualAddressFields) ...[
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
                  controller: widget.streetController,
                  label: 'Rua',
                  hintText: 'Nome da rua',
                  isRequired:
                      true, // ✅ CORREÇÃO BUG #8: Rua também é obrigatória
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormField(
                    controller: widget.numberController,
                    label: 'Número',
                    hintText: '',
                    isNumber: true,
                    isRequired: true,
                  ),
                  const SizedBox(
                    height: 20,
                  ), // Compensação para alinhar com complemento
                ],
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
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
            onTap:
                () => widget.onFavoriteLabelChanged(
                  widget.favoriteLabel == 'Casa' ? '' : 'Casa',
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFavoriteButton(
            icon: Icons.work,
            label: 'Trabalho',
            isSelected: widget.favoriteLabel == 'Trabalho',
            onTap:
                () => widget.onFavoriteLabelChanged(
                  widget.favoriteLabel == 'Trabalho' ? '' : 'Trabalho',
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
          color: isSelected ? Colors.black : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.black : const Color(0xFF3F3E3E),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : const Color(0xFF3F3E3E),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
    return const Icon(Icons.location_on, color: Colors.red, size: 32);
  }
}

// ✅ CORREÇÃO BUG #10: Widget do Label com suporte a retry
class _PinLabel extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback? onRetry;

  const _PinLabel({
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage = '',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasError ? onRetry : null,
      child: Container(
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
            color: hasError ? Colors.red.shade300 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 4),
              Text(
                'Buscando endereço...',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else if (hasError) ...[
              Icon(Icons.error_outline, size: 20, color: Colors.red.shade400),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
