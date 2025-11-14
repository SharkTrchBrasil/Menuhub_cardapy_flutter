// lib/pages/profile/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/app_text_field.dart';

import '../../core/di.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final customer = context.read<AuthCubit>().state.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(
        customerRepository: getIt<CustomerRepository>(),
        orderRepository: getIt<OrderRepository>(),
      )..loadProfile(context.read<AuthCubit>().state.customer),
      child: BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.status == ProfileStatus.success && !state.isUpdating) {
          // Atualiza o AuthCubit com o cliente atualizado
          if (state.customer != null) {
            context.read<AuthCubit>().updateCustomer(state.customer!);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          if (mounted) context.pop();
        } else if (state.status == ProfileStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Erro ao atualizar perfil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final customer = context.watch<AuthCubit>().state.customer;
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar Perfil')),
            body: const Center(child: Text('Cliente não encontrado')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Editar Perfil'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildPhotoSection(context, customer),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _nameController,
                  title: 'Nome completo',
                  hint: 'Digite seu nome',
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Nome deve ter no mínimo 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  title: 'E-mail',
                  hint: 'seu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  enabled: false, // Email não pode ser alterado normalmente
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  title: 'Telefone',
                  hint: '(00) 00000-0000',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, state) {
                    final isLoading = state.isUpdating || _isUploadingPhoto;
                    return DsPrimaryButton(
                      onPressed: isLoading ? null : _saveProfile,
                      label: isLoading ? 'Salvando...' : 'Salvar alterações',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context, Customer customer) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: customer.photo != null && customer.photo!.isNotEmpty
              ? NetworkImage(customer.photo!)
              : null,
          child: customer.photo == null || customer.photo!.isEmpty
              ? const Icon(Icons.person, size: 60)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: IconButton(
              icon: _isUploadingPhoto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              onPressed: _isUploadingPhoto ? null : _pickImage,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() => _isUploadingPhoto = true);
        final customer = context.read<AuthCubit>().state.customer;
        if (customer != null) {
          await context.read<ProfileCubit>().updateProfilePhoto(customer.id!, image);
        }
        setState(() => _isUploadingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveProfile() {
    final customer = context.read<AuthCubit>().state.customer;
    if (customer == null) return;

    context.read<ProfileCubit>().updateProfile(
      customerId: customer.id!,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
    );
  }
}

