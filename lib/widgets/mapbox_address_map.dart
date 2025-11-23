// lib/widgets/mapbox_address_map.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:collection/collection.dart';
import 'package:totem/models/store.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/services/reverse_geocoding_service.dart';

/// Widget de mapa interativo com formulário sobreposto (estilo iFood)
/// O formulário aparece como um bottom sheet sobre o mapa
class MapboxAddressMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String? addressDescription;
  final Store store;
  final Function(double latitude, double longitude, Map<String, String> formData) onConfirmed;
  final VoidCallback onBack;

  const MapboxAddressMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.addressDescription,
    required this.store,
    required this.onConfirmed,
    required this.onBack,
  });

  @override
  State<MapboxAddressMap> createState() => _MapboxAddressMapState();
}

class _MapboxAddressMapState extends State<MapboxAddressMap> {
  final MapController _mapController = MapController();
  final _formKey = GlobalKey<FormState>();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  late double _currentLatitude;
  late double _currentLongitude;
  bool _showForm = false;
  bool _isDraggingMarker = false; // ✅ NOVO: Controla se está arrastando o marcador
  Timer? _reverseGeocodeTimer; // ✅ NOVO: Timer para debounce do reverse geocoding

  // Controllers do formulário
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _complementController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  
  String? _selectedFavorite; // 'casa' ou 'trabalho'
  
  // ✅ ATUALIZADO: Apenas cidade (bairro é texto livre capturado do mapa)
  StoreCity? _selectedCity;

  @override
  void initState() {
    super.initState();
    _currentLatitude = widget.initialLatitude;
    _currentLongitude = widget.initialLongitude;
    
    // Preenche rua se tiver descrição
    if (widget.addressDescription != null) {
      _streetController.text = widget.addressDescription!.split(',').first;
    }
    
    // ✅ Seleciona cidade padrão se houver apenas uma
    if (widget.store.cities.length == 1) {
      _selectedCity = widget.store.cities.first;
    }
    
    // ✅ NOVO: Faz reverse geocoding para preencher endereço automaticamente
    _reverseGeocodeAddress(_currentLatitude, _currentLongitude);
  }
  
  /// ✅ NOVO: Faz reverse geocoding para preencher endereço do mapa (incluindo bairro)
  Future<void> _reverseGeocodeAddress(double latitude, double longitude) async {
    try {
      // Importa o serviço de reverse geocoding
      final addressData = await ReverseGeocodingService.getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );

      if (addressData != null && mounted) {
        setState(() {
          // ✅ CRÍTICO: Sempre atualiza rua quando o mapa é movido
          if (addressData['street'] != null && addressData['street'].toString().isNotEmpty) {
            _streetController.text = addressData['street'] as String;
          }

          // Preenche número apenas se estiver vazio (não sobrescreve se o usuário já digitou)
          if (_numberController.text.trim().isEmpty && addressData['number'] != null) {
            _numberController.text = addressData['number'] as String;
          }

          // ✅ CRÍTICO: Sempre atualiza bairro quando o mapa é movido
          if (addressData['neighborhood'] != null && addressData['neighborhood'].toString().isNotEmpty) {
            _neighborhoodController.text = addressData['neighborhood'] as String;
          } else {
            // Se não encontrou bairro, limpa o campo
            _neighborhoodController.clear();
          }

          // Preenche cidade se não tiver selecionada
          if (_selectedCity == null && addressData['city'] != null) {
            final cityName = addressData['city'] as String;
            final matchingCity = widget.store.cities.firstWhereOrNull(
              (c) => c.name.toLowerCase() == cityName.toLowerCase(),
            );
            if (matchingCity != null) {
              _selectedCity = matchingCity;
            }
          }
        });
      }
    } catch (e) {
      print('⚠️ Erro ao fazer reverse geocoding: $e');
      // Não mostra erro ao usuário, apenas loga
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_showForm) {
      setState(() {
        _currentLatitude = point.latitude;
        _currentLongitude = point.longitude;
      });
      // ✅ NOVO: Faz reverse geocoding quando usuário toca no mapa
      _reverseGeocodeAddress(point.latitude, point.longitude);
    }
  }

  void _confirmLocation() {
    setState(() {
      _showForm = true;
    });
    
    // ✅ NOVO: Faz reverse geocoding quando usuário confirma localização
    _reverseGeocodeAddress(_currentLatitude, _currentLongitude);
    
    // Anima o sheet para aparecer
    Future.delayed(const Duration(milliseconds: 100), () {
      _sheetController.animateTo(
        0.7, // 70% da tela
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _saveAddress() {
    if (_formKey.currentState!.validate()) {
      final formData = {
        'street': _streetController.text,
        'number': _numberController.text,
        'complement': _complementController.text,
        'apartment': _apartmentController.text,
        'reference': _referenceController.text,
        'favorite': _selectedFavorite ?? '',
        'city': _selectedCity?.name ?? '',
        'cityId': _selectedCity?.id.toString() ?? '',
        'neighborhood': _neighborhoodController.text.trim(),
        'neighborhoodId': '', // ✅ ATUALIZADO: Não usa mais neighborhood_id
      };
      
      widget.onConfirmed(_currentLatitude, _currentLongitude, formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    if (mapboxToken.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          title: const Text('Confirme a localização'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Token do Mapbox não configurado.\n\nAdicione MAPBOX_ACCESS_TOKEN no arquivo assets/env',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    // ✅ ATUALIZADO: Removida lógica de bairros cadastrados - agora sempre usa texto livre

    return Scaffold(
      body: Stack(
        children: [
          // Mapa usando Flutter Map com tiles do Mapbox
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_currentLatitude, _currentLongitude),
              initialZoom: 16.0,
              onTap: _onMapTap,
              // ✅ NOVO: Detecta quando o usuário termina de arrastar o mapa
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd) {
                  // Quando o usuário termina de arrastar o mapa, atualiza o marcador e faz reverse geocoding
                  final center = _mapController.camera.center;
                  setState(() {
                    _currentLatitude = center.latitude;
                    _currentLongitude = center.longitude;
                  });
                  // ✅ CRÍTICO: Faz reverse geocoding para atualizar o endereço completo
                  _reverseGeocodeAddress(center.latitude, center.longitude);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Layer de tiles do Mapbox
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                userAgentPackageName: 'com.menuhub.totem',
                tileSize: 512,
                zoomOffset: -1,
              ),
              
              // Marcador na posição atual (sempre centralizado)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_currentLatitude, _currentLongitude),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // AppBar transparente sobre o mapa
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              title: Text(_showForm ? 'Complete o endereço' : 'Confirme a localização'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),

          // Botão de confirmar (apenas quando não está mostrando o form)
          if (!_showForm)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Confirmar localização',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ✅ FORMULÁRIO COMO BOTTOM SHEET (estilo iFood)
          if (_showForm)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.7, // 70% da tela
              minChildSize: 0.5, // Mínimo 50%
              maxChildSize: 0.9, // Máximo 90%
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle do drag
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Conteúdo do formulário
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Endereço selecionado
                              if (widget.addressDescription != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.addressDescription!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ✅ CIDADE (se houver mais de uma)
                              if (widget.store.cities.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<StoreCity>(
                                    value: _selectedCity,
                                    decoration: InputDecoration(
                                      labelText: 'Cidade *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: widget.store.cities.map<DropdownMenuItem<StoreCity>>((city) {
                                      return DropdownMenuItem<StoreCity>(
                                        value: city,
                                        child: Text(city.name),
                                      );
                                    }).toList(),
                                    onChanged: (city) {
                                      setState(() {
                                        _selectedCity = city;
                                        _neighborhoodController.clear(); // Reset bairro
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Selecione uma cidade';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                              // ✅ ATUALIZADO: Bairro como campo de texto livre (capturado do mapa)
                              TextFormField(
                                controller: _neighborhoodController,
                                decoration: InputDecoration(
                                  labelText: 'Bairro *',
                                  hintText: 'Digite seu bairro',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Campo obrigatório';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Rua
                              TextFormField(
                                controller: _streetController,
                                decoration: InputDecoration(
                                  labelText: 'Rua',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite a rua';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Número
                              TextFormField(
                                controller: _numberController,
                                decoration: InputDecoration(
                                  labelText: 'Número *',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Digite o número';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Complemento
                              TextFormField(
                                controller: _complementController,
                                decoration: InputDecoration(
                                  labelText: 'Complemento',
                                  hintText: 'Ex: Próximo ao mercado',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Apartamento/Bloco/Casa
                              TextFormField(
                                controller: _apartmentController,
                                decoration: InputDecoration(
                                  labelText: 'Apartamento/Bloco/Casa',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Ponto de referência
                              TextFormField(
                                controller: _referenceController,
                                decoration: InputDecoration(
                                  labelText: 'Ponto de referência',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Favoritar como
                              const Text(
                                'Favoritar como',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedFavorite = _selectedFavorite == 'casa' ? null : 'casa';
                                        });
                                      },
                                      icon: Icon(
                                        Icons.home_outlined,
                                        color: _selectedFavorite == 'casa' 
                                            ? Theme.of(context).primaryColor 
                                            : Colors.grey,
                                      ),
                                      label: Text(
                                        'Casa',
                                        style: TextStyle(
                                          color: _selectedFavorite == 'casa' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: _selectedFavorite == 'casa' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.grey.shade300,
                                          width: _selectedFavorite == 'casa' ? 2 : 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedFavorite = _selectedFavorite == 'trabalho' ? null : 'trabalho';
                                        });
                                      },
                                      icon: Icon(
                                        Icons.work_outline,
                                        color: _selectedFavorite == 'trabalho' 
                                            ? Theme.of(context).primaryColor 
                                            : Colors.grey,
                                      ),
                                      label: Text(
                                        'Trabalho',
                                        style: TextStyle(
                                          color: _selectedFavorite == 'trabalho' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: _selectedFavorite == 'trabalho' 
                                              ? Theme.of(context).primaryColor 
                                              : Colors.grey.shade300,
                                          width: _selectedFavorite == 'trabalho' ? 2 : 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Botões de ação
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showForm = false;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      child: const Text('Voltar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _saveAddress,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Salvar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reverseGeocodeTimer?.cancel();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _apartmentController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}
