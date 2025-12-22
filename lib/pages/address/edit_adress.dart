import 'package:collection/collection.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/pages/address/widgets/clean_text_field.dart';
import 'package:totem/services/geolocation_service.dart';
import 'package:totem/services/reverse_geocoding_service.dart';

import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/store_cubit.dart';
import 'cubits/address_cubit.dart';

class EditAddressPage extends StatefulWidget {
  final CustomerAddress? addressToEdit;
  final bool startWithMap; // ✅ NOVO: Flag para iniciar com o mapa

  const EditAddressPage({
    super.key,
    this.addressToEdit,
    this.startWithMap = false,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  late CustomerAddress _currentAddress;
  late final TextEditingController _streetController;
  late final TextEditingController _numberController;
  late final TextEditingController _complementController;
  late final TextEditingController _referenceController;
  late final TextEditingController _neighborhoodTextController;

  StoreCity? _selectedCity;
  late String _selectedLabel;
  late bool _noComplement;
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;
  
  // ✅ NOVO: Dados do endereço vindos do mapa (não editáveis)
  String? _mapStreet;
  String? _mapNeighborhood;
  String? _mapCity;
  String? _mapState;

  @override
  void initState() {
    super.initState();
    _initializeAddressState();
  }

  void _initializeAddressState() {
    final store = context.read<StoreCubit>().state.store;
    _currentAddress = widget.addressToEdit ?? CustomerAddress.empty();

    // ✅ ATUALIZADO: Número, complemento, referência e bairro (quando necessário) são editáveis
    _numberController = TextEditingController(text: _currentAddress.number);
    _complementController = TextEditingController(text: _currentAddress.complement);
    _referenceController = TextEditingController(text: _currentAddress.reference);
    _neighborhoodTextController = TextEditingController(text: _currentAddress.neighborhood);

    _selectedLabel = _currentAddress.label;
    _noComplement = _currentAddress.complement == null || _currentAddress.complement!.isEmpty;
    _latitude = _currentAddress.latitude;
    _longitude = _currentAddress.longitude;
    
    // ✅ NOVO: Preenche dados do mapa se já tiver endereço (modo edição)
    if (widget.addressToEdit != null) {
      _mapStreet = _currentAddress.street;
      _mapNeighborhood = _currentAddress.neighborhood;
      _mapCity = _currentAddress.city;
      _mapState = ''; // Estado pode não estar no modelo
      
      // Se tiver coordenadas, pode fazer reverse geocoding para atualizar dados do mapa
      if (_latitude != null && _longitude != null) {
        // Faz reverse geocoding em background para atualizar dados do mapa
        _reverseGeocodeAddress(_latitude!, _longitude!);
      }
    }

    // Se for novo endereço, tenta pegar localização automaticamente ou abrir o mapa
    if (widget.addressToEdit == null) {
      if (widget.startWithMap) {
        // ✅ NOVO: Se solicitado, abre o mapa imediatamente após o build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openMap(context);
        });
      } else {
        _getCurrentLocation();
      }
    }

    if (widget.addressToEdit != null && store != null) {
      if (_currentAddress.cityId != null) {
        try {
          _selectedCity = store.cities.firstWhere((c) => c.id == _currentAddress.cityId);
        } catch (e) {
          print("Aviso: Cidade do endereço salvo não encontrado nas regras da loja. $e");
          _selectedCity = null;
        }
      }
    } else if (widget.addressToEdit == null && store != null && store.cities.length == 1) {
      _selectedCity = store.cities.first;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _complementController.dispose();
    _referenceController.dispose();
    _neighborhoodTextController.dispose();
    _complementController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreCubit>().state.store;
    final isNewAddress = widget.addressToEdit == null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (store == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Erro: Informações da loja não encontradas.',
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.error),
          ),
        ),
      );
    }

    // ✅ ATUALIZADO: Endereço vem do mapa, cliente só digita número, complemento e referência

    return Scaffold(
      // ✅ NOVO: Remove bordas do Scaffold quando está dentro de um Dialog
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isNewAddress ? 'Novo Endereço' : 'Editar Endereço'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ClipRRect(
        // ✅ NOVO: Garante que o conteúdo respeite as bordas arredondadas do Dialog
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // ✅ NOVO: Exibe endereço completo do mapa no topo
              if (_mapStreet != null && _mapStreet!.isNotEmpty)
                _buildAddressDisplay(context),
              
              // ✅ NOVO: Botão para confirmar localização no mapa (se não tiver endereço)
              if (_mapStreet == null || _mapStreet!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map),
                    label: Text(_isGettingLocation ? 'Obtendo endereço...' : 'Confirmar localização no mapa'),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Detalhes do endereço'),
              const SizedBox(height: 16),

              // ✅ NOVO: Campo de bairro (apenas se o mapa NÃO encontrou)
              // Quando o mapa encontra, o bairro aparece apenas no header
              if (_mapNeighborhood == null || _mapNeighborhood!.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bairro',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _neighborhoodTextController,
                      validator: (value) {
                        // ✅ CRÍTICO: Obrigatório se o mapa não encontrou o bairro
                        if (value == null || value.trim().isEmpty) {
                          return 'Informar o bairro';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Digite o bairro',
                        filled: true,
                        fillColor: colors.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          // ✅ Borda vermelha quando obrigatório
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          // ✅ Borda vermelha ao focar
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    // ✅ Mensagem de erro abaixo do campo
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        'Informar o bairro',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: CleanTextField(
                      controller: _numberController,
                      title: 'Número',
                      hint: '123',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: CleanTextField(
                      controller: _complementController,
                      title: 'Complemento',
                      hint: 'Apartamento/Bloco/Casa',
                      enabled: !_noComplement,
                      validator: (value) {
                        if (!_noComplement && (value == null || value.isEmpty)) {
                          return 'Obrigatório';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              // Usando CheckboxListTile para um visual mais limpo
              CheckboxListTile(
                value: _noComplement,
                onChanged: (bool? value) {
                  setState(() {
                    _noComplement = value ?? false;
                    if (_noComplement) _complementController.clear();
                    // Revalida o campo de complemento ao marcar/desmarcar
                    _formKey.currentState?.validate();
                  });
                },
                title: Text('Sem complemento', style: theme.textTheme.bodyMedium),
                controlAffinity: ListTileControlAffinity.leading, // Checkbox na esquerda
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 16),

              CleanTextField(
                controller: _referenceController,
                title: 'Ponto de referência (opcional)',
                hint: 'Próximo ao mercado X',
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(context, 'Marcar como'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLabelButton(context, icon: Icons.home_outlined, label: 'Casa'),
                  _buildLabelButton(context, icon: Icons.work_outline, label: 'Trabalho'),
                  _buildLabelButton(context, icon: Icons.favorite_border, label: 'Favorito'),
                ],
              ),
              const SizedBox(height: 32), // Espaço antes do botão

              // ✅ BOTÃO MOVIDO PARA CÁ
              // Ele agora é o último item da lista e vai rolar junto com o resto.
              Padding(
                // Adiciona um padding na parte inferior para não colar no fim da tela
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DsPrimaryButton(
                  onPressed: _handleSave,
                  label: isNewAddress ? 'Salvar endereço' : 'Atualizar endereço',
                ),
              ),

            ],
          ),
        ),
        ),
      ),

    );
  }

  // ✅ NOVO: Widget para exibir endereço completo do mapa
  Widget _buildAddressDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final addressLine = _mapStreet ?? '';
    final cityLine = _mapNeighborhood != null && _mapNeighborhood!.isNotEmpty
        ? '$_mapNeighborhood, $_mapCity'
        : _mapCity ?? '';
    final stateLine = _mapState != null && _mapState!.isNotEmpty ? ' - $_mapState' : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  addressLine,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (cityLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                '$cityLine$stateLine',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.edit_location_alt, size: 16),
            label: const Text('Alterar localização no mapa'),
            onPressed: () => _openMap(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NOVO: Método extraído para abrir o mapa
  Future<void> _openMap(BuildContext context) async {
    final store = context.read<StoreCubit>().state.store;
    if (store == null) return;
    
    final result = await context.push<Map<String, dynamic>>(
      '/address-map',
      extra: {
        'initialLatitude': _latitude,
        'initialLongitude': _longitude,
        'addressDescription': _mapStreet,
        'store': store,
      },
    );
    
    if (result != null && mounted) {
      // ✅ CRÍTICO: Atualiza endereço quando o usuário escolhe nova localização no mapa
      setState(() {
        _latitude = result['latitude'] as double;
        _longitude = result['longitude'] as double;
        _mapStreet = result['formData']['street'] as String?;
        _mapNeighborhood = result['formData']['neighborhood'] as String?;
        _mapCity = result['formData']['city'] as String?;
        _mapState = result['formData']['state'] as String?;
        
        // Atualiza campos editáveis
        if (result['formData']['number'] != null) {
          _numberController.text = result['formData']['number'] as String? ?? '';
        }
        if (result['formData']['complement'] != null) {
          _complementController.text = result['formData']['complement'] as String? ?? '';
        }
        if (result['formData']['reference'] != null) {
          _referenceController.text = result['formData']['reference'] as String? ?? '';
        }
        
        // ✅ CRÍTICO: Atualiza bairro - se não encontrou, limpa para mostrar o campo
        if (_mapNeighborhood != null && _mapNeighborhood!.isNotEmpty) {
          _neighborhoodTextController.text = _mapNeighborhood!;
        } else {
          _neighborhoodTextController.clear();
        }
        
        // Atualiza cidade selecionada
        final cityName = result['formData']['city'] as String?;
        if (cityName != null && cityName.isNotEmpty) {
          final matchingCity = store.cities.firstWhereOrNull(
            (c) => c.name.toLowerCase() == cityName.toLowerCase(),
          );
          if (matchingCity != null) {
            _selectedCity = matchingCity;
          }
        }
      });
    }
  }

  // Widget auxiliar para títulos de seção
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLabelButton(BuildContext context, {required IconData icon, required String label}) {
    final theme = Theme.of(context);
    final isSelected = _selectedLabel == label;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedLabel = selected ? label : ''),
      backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.2),
      selectedColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }


  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final customerId = context.read<AuthCubit>().state.customer?.id;
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: cliente não autenticado.')),
      );
      return;
    }

    // ✅ ATUALIZADO: Valida se tem endereço do mapa
    if (_mapStreet == null || _mapStreet!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário confirmar a localização no mapa primeiro.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // ✅ ATUALIZADO: Usa dados do mapa (não editáveis) + dados digitados pelo cliente
    final finalAddress = _currentAddress.copyWith(
      label: _selectedLabel.isNotEmpty ? _selectedLabel : 'Endereço',
      street: _mapStreet!,
      number: _numberController.text.trim(),
      complement: _noComplement ? '' : _complementController.text.trim(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      city: _mapCity ?? (_selectedCity?.name ?? ''),
      cityId: _selectedCity?.id,

      // ✅ CRÍTICO: Usa bairro do mapa se encontrou, senão usa o que o cliente digitou
      neighborhood: (_mapNeighborhood != null && _mapNeighborhood!.isNotEmpty) 
          ? _mapNeighborhood! 
          : _neighborhoodTextController.text.trim(),
      neighborhoodId: null, // ✅ ATUALIZADO: Não usa mais neighborhood_id
      isFavorite: _selectedLabel.isNotEmpty,
      latitude: () => _latitude,
      longitude: () => _longitude,
    );

    context.read<AddressCubit>().saveAddress(customerId, finalAddress);
    context.pop();
  }

  Future<void> _getCurrentLocation() async {
    final position = await GeolocationService.getCurrentPosition();

    if (position != null) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // ✅ NOVO: Faz reverse geocoding para preencher endereço automaticamente do mapa
      await _reverseGeocodeAddress(position.latitude, position.longitude);
    } else {
      setState(() => _isGettingLocation = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter sua localização. Permita o acesso à localização nas configurações.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// ✅ NOVO: Faz reverse geocoding para preencher endereço do mapa (incluindo bairro)
  Future<void> _reverseGeocodeAddress(double latitude, double longitude) async {
    setState(() => _isGettingLocation = true);
    
    try {
      final addressData = await ReverseGeocodingService.getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );

      if (addressData != null && mounted) {
        final store = context.read<StoreCubit>().state.store;
        if (store == null) {
          setState(() => _isGettingLocation = false);
          return;
        }

        setState(() {
          // ✅ CRÍTICO: Preenche dados do mapa (não editáveis)
          _mapStreet = addressData['street'] as String? ?? '';
          
          // ✅ CRÍTICO: Atualiza bairro - se não encontrar, deixa null para mostrar o campo
          final neighborhoodFromMap = addressData['neighborhood'] as String?;
          if (neighborhoodFromMap != null && neighborhoodFromMap.trim().isNotEmpty) {
            _mapNeighborhood = neighborhoodFromMap.trim();
            _neighborhoodTextController.text = _mapNeighborhood!;
          } else {
            // ✅ CRÍTICO: Se não encontrou bairro, limpa e deixa null para mostrar o campo
            _mapNeighborhood = null;
            _neighborhoodTextController.clear();
          }
          
          _mapCity = addressData['city'] as String? ?? '';
          _mapState = addressData['state'] as String? ?? '';

          // Preenche número se estiver vazio (pode vir do geocoding)
          if (_numberController.text.trim().isEmpty && addressData['number'] != null) {
            _numberController.text = addressData['number'] as String;
          }

          // Preenche cidade selecionada se não tiver
          if (_selectedCity == null && _mapCity != null && _mapCity!.isNotEmpty) {
            final matchingCity = store.cities.firstWhereOrNull(
              (c) => c.name.toLowerCase() == _mapCity!.toLowerCase(),
            );
            if (matchingCity != null) {
              _selectedCity = matchingCity;
            }
          }
          
          _isGettingLocation = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Endereço obtido do mapa com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _isGettingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível obter o endereço. Tente novamente.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isGettingLocation = false);
      print('⚠️ Erro ao fazer reverse geocoding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao obter endereço. Verifique sua conexão e tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}