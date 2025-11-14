// lib/pages/auth/reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/app_text_field.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recuperar senha')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Email enviado!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enviamos um link de recuperação para ${_emailController.text}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Digite seu e-mail para receber um link de recuperação de senha',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _emailController,
                title: 'E-mail',
                hint: 'seu@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              DsPrimaryButton(
                onPressed: _handleResetPassword,
                label: 'Enviar link de recuperação',
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AuthCubit>().resetPassword(_emailController.text.trim());
      setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

