// lib/pages/profile/profile_page_complete.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/core/di.dart';
import 'package:brasil_fields/brasil_fields.dart';

class ProfilePageComplete extends StatelessWidget {
  const ProfilePageComplete({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final customer = authState.customer;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(
          child: Text('Faça login para acessar seu perfil'),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ProfileCubit(
        customerRepository: getIt<CustomerRepository>(),
        orderRepository: getIt<OrderRepository>(),
      )..loadProfile(customer),
      child: const ProfilePageView(),
    );
  }
}

class ProfilePageView extends StatelessWidget {
  const ProfilePageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ProfileStatus.error) {
            return Center(child: Text('Erro: ${state.errorMessage}'));
          }

          final customer = state.customer!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Foto e informações básicas
                _ProfileHeader(customer: customer),
                const SizedBox(height: 24),

                // Editar perfil
                _EditProfileSection(customer: customer),
                const SizedBox(height: 24),

                // Histórico de pedidos
                _OrderHistorySection(orders: state.filteredOrders),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final customer;

  const _ProfileHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: customer.photo != null && customer.photo!.isNotEmpty
                  ? NetworkImage(customer.photo!)
                  : null,
              child: customer.photo == null || customer.photo!.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  onPressed: () => _pickImage(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          customer.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          customer.email,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && context.mounted) {
      await context.read<ProfileCubit>().updateProfilePhoto(customer.id!, image);
    }
  }
}

class _EditProfileSection extends StatefulWidget {
  final customer;

  const _EditProfileSection({required this.customer});

  @override
  State<_EditProfileSection> createState() => _EditProfileSectionState();
}

class _EditProfileSectionState extends State<_EditProfileSection> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Informações Pessoais', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit),
                  onPressed: _isEditing ? _saveProfile : () => setState(() => _isEditing = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,

            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    context.read<ProfileCubit>().updateProfile(
      customerId: widget.customer.id!,
      name: _nameController.text,
      phone: _phoneController.text,
    );
    setState(() => _isEditing = false);
  }
}

class _OrderHistorySection extends StatelessWidget {
  final List<Order> orders;

  const _OrderHistorySection({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Histórico de Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Nenhum pedido encontrado'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final totalPrice = order.charge?.amount ?? 0;
                  return ListTile(
                    title: Text('Pedido #${order.publicId}'),
                    subtitle: Text('R\$ ${(totalPrice / 100.0).toStringAsFixed(2).replaceAll('.', ',')} - ${order.orderStatus}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/order/${order.id}'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

