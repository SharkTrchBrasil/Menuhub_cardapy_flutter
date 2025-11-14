import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/store_city.dart';
import 'package:totem/models/store_neig.dart';
import 'package:totem/pages/address/widgets/clean_text_field.dart';
import 'package:totem/services/geolocation_service.dart';

import 'package:totem/widgets/ds_primary_button.dart';
import '../../cubit/store_cubit.dart';
import 'cubits/address_cubit.dart';

class EditAddressPage extends StatefulWidget {
  const EditAddressPage({
    super.key,
    this.addressToEdit,
  });

  final CustomerAddress? addressToEdit;

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
  StoreNeighborhood? _selectedNeighborhood;
  late String _selectedLabel;
  late bool _noComplement;
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeAddressState();
  }

  void _initializeAddressState() {
    final store = context.read<StoreCubit>().state.store;
    _currentAddress = widget.addressToEdit ?? CustomerAddress.empty();

    _streetController = TextEditingController(text: _currentAddress.street);
    _numberController = TextEditingController(text: _currentAddress.number);
    _complementController = TextEditingController(text: _currentAddress.complement);
    _referenceController = TextEditingController(text: _currentAddress.reference);
    _neighborhoodTextController = TextEditingController(text: _currentAddress.neighborhood);

    _selectedLabel = _currentAddress.label;
    _noComplement = _currentAddress.complement == null || _currentAddress.complement!.isEmpty;
    _latitude = _currentAddress.latitude;
    _longitude = _currentAddress.longitude;

    // Se for novo endereço, tenta pegar localização automaticamente
    if (widget.addressToEdit == null) {
      _getCurrentLocation();
    }

    if (widget.addressToEdit != null && store != null) {
      if (_currentAddress.cityId != null) {
        try {
          _selectedCity = store.cities.firstWhere((c) => c.id == _currentAddress.cityId);
          if (_currentAddress.neighborhoodId != null) {
            _selectedNeighborhood = _selectedCity!.neighborhoods.firstWhere((n) => n.id == _currentAddress.neighborhoodId);
          }
        } catch (e) {
          print("Aviso: Cidade/bairro do endereço salvo não encontrado nas regras da loja. $e");
          _selectedCity = null;
          _selectedNeighborhood = null;
        }
      }
    } else if (widget.addressToEdit == null && store != null && store.cities.length == 1) {
      _selectedCity = store.cities.first;
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _referenceController.dispose();
    _neighborhoodTextController.dispose();
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

    // ✅ CRÍTICO: Verificar se há regra neighborhood_fee ATIVA (não apenas deliveryScope antigo)
    final hasNeighborhoodFeeRule = store.deliveryFeeRules.any(
      (r) => r.ruleType == 'neighborhood_fee' && r.isActive,
    );
    // Fallback para compatibilidade com sistema antigo
    final deliveryScopeIsNeighborhood = store.store_operation_config?.deliveryScope == 'neighborhood';
    final requiresNeighborhoodSelection = hasNeighborhoodFeeRule || deliveryScopeIsNeighborhood;

    // ✅ CRÍTICO: Verificar se frete por km/raio requer coordenadas
    final requiresCoordinates = store.deliveryFeeRules.any(
      (r) => r.isActive && (r.ruleType == 'per_km' || r.ruleType == 'radius'),
    );

    return Scaffold(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'Localização'),
              const SizedBox(height: 16),

              // ✅ CRÍTICO: Mostrar aviso se coordenadas são obrigatórias
              if (requiresCoordinates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'É necessário capturar sua localização para calcular o frete.',
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Botão para pegar localização atual
              if (_latitude == null || _longitude == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isGettingLocation ? 'Obtendo localização...' : 'Usar minha localização'),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  ),
                ),

              if (_latitude != null && _longitude != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Localização capturada: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _getCurrentLocation,
                          child: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                ),

              CleanSelectionFormField<StoreCity>(
                initialValue: _selectedCity,
                title: 'Cidade',
                fetch: () async => Right(store.cities),
                onChanged: (city) => setState(() {
                  _selectedCity = city;
                  _selectedNeighborhood = null;
                  _neighborhoodTextController.clear();
                }),
                validator: (v) => v == null ? 'Selecione uma cidade' : null,
              ),
              const SizedBox(height: 16),

              if (requiresNeighborhoodSelection)
                CleanSelectionFormField<StoreNeighborhood>(
                  title: 'Bairro',
                  initialValue: _selectedNeighborhood,
                  fetch: () async => Right(_selectedCity?.neighborhoods ?? []),
                  onChanged: (neighborhood) => setState(() => _selectedNeighborhood = neighborhood),
                  validator: (v) => v == null ? 'Selecione um bairro' : null,
                )
              else
                CleanTextField(
                  controller: _neighborhoodTextController,
                  title: 'Bairro',
                  hint: 'Digite seu bairro',
                  validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
                ),

              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Endereço'),
              const SizedBox(height: 16),

              CleanTextField(
                controller: _streetController,
                title: 'Rua/Avenida',
                hint: 'Nome da rua ou avenida',
                validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

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
                      hint: 'Apto, Bloco, Casa',
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

    );
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

    // ✅ CRÍTICO: Verificar se há regra neighborhood_fee ATIVA
    final storeState = context.read<StoreCubit>().state.store;
    final hasNeighborhoodFeeRule = storeState?.deliveryFeeRules.any(
      (r) => r.ruleType == 'neighborhood_fee' && r.isActive,
    ) ?? false;
    // Fallback para compatibilidade com sistema antigo
    final deliveryScopeIsNeighborhood = storeState?.store_operation_config?.deliveryScope == 'neighborhood';
    final requiresNeighborhoodSelection = hasNeighborhoodFeeRule || deliveryScopeIsNeighborhood;

    final finalAddress = _currentAddress.copyWith(
      label: _selectedLabel.isNotEmpty ? _selectedLabel : 'Endereço',
      street: _streetController.text.trim(),
      number: _numberController.text.trim(),
      complement: _noComplement ? '' : _complementController.text.trim(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      city: _selectedCity!.name,
      cityId: _selectedCity!.id,

      neighborhood: requiresNeighborhoodSelection ? _selectedNeighborhood!.name : _neighborhoodTextController.text.trim(),
      neighborhoodId: requiresNeighborhoodSelection ? _selectedNeighborhood!.id : null,
      isFavorite: _selectedLabel.isNotEmpty,
      latitude: () => _latitude,
      longitude: () => _longitude,
    );

    context.read<AddressCubit>().saveAddress(customerId, finalAddress);
    context.pop();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    final position = await GeolocationService.getCurrentPosition();

    if (position != null) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localização capturada com sucesso!'),
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
            content: Text('Não foi possível obter sua localização. Permita o acesso à localização nas configurações.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}