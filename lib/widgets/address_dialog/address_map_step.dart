import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Step 1: Mapa para confirmar localização - Versão simplificada
class AddressMapStep extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const AddressMapStep({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    return Stack(
      key: const ValueKey('map'),
      children: [
        // Mapa real usando Flutter Map com tiles do Mapbox
        if (mapboxToken.isNotEmpty)
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
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
        // Fallback se não tiver token do Mapbox
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

        // Cabeçalho superior
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: _buildHeader(context),
        ),

        // PIN VERMELHO FIXO NO CENTRO DO MAPA COM TEXTO
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Label/Nome acima do pin vermelho
              _PinLabel(),
              SizedBox(height: 4),
              // Pin vermelho (substitui o preto)
              _RedPin(),
            ],
          ),
        ),

        // Botão de confirmar
        Positioned(
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          left: 16,
          right: 16,
          child: _buildConfirmButton(context),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribui espaço igualmente
        children: [
          // Botão voltar
          IconButton(
            onPressed: onBack,
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

          // Título centralizado
          Text(
            'ENDEREÇO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),

          // Espaço invisível para balancear
          Opacity(
            opacity: 0,
            child: IconButton(
              onPressed: null,
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
              ),
            ),
          ),
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
      onPressed: onConfirm,
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
}

// Widget do Pin VERMELHO (substitui o preto)
class _RedPin extends StatelessWidget {
  const _RedPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,

      child: const Icon(
        Icons.location_on,
        color: Colors.red,
        size: 32,
      ),
    );
  }
}

// Widget do Label acima do pin vermelho
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
            'Você esta aqui ?', // Exemplo do seu texto
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
            'Ajuste a localização', // Exemplo do seu texto
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

// Versão alternativa se você quiser passar o texto dinamicamente:
class _PinLabelDynamic extends StatelessWidget {
  final String mainText;
  final String subText;

  const _PinLabelDynamic({
    required this.mainText,
    required this.subText,
  });

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
            mainText,
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
            subText,
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