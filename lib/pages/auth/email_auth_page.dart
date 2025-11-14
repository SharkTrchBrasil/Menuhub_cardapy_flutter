// lib/pages/auth/email_auth_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';
import 'package:totem/widgets/app_text_field.dart';

class EmailAuthPage extends StatefulWidget {
  final bool isSignUp;
  
  const EmailAuthPage({
    super.key,
    this.isSignUp = false,
  });

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSignUp ? 'Criar conta' : 'Entrar'),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) {
            context.pop(true);
          } else if (state.status == AuthStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Erro ao autenticar'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isSignUp) ...[
                  AppTextField(
                    controller: _nameController,
                    title: 'Nome completo',
                    hint: 'Digite seu nome',
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Nome deve ter no mínimo 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordController,
                    title: 'Senha',
                    hint: 'Digite sua senha',
                    isHidden: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Senha deve ter no mínimo 6 caracteres';
                      }
                      if (widget.isSignUp) {
                        // Validações mais rigorosas para sign up
                        if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
                          return 'Senha deve conter pelo menos uma letra';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Senha deve conter pelo menos um número';
                        }
                      }
                      return null;
                    },
                  ),
                if (widget.isSignUp) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirmPasswordController,
                    title: 'Confirmar senha',
                    hint: 'Digite sua senha novamente',
                    isHidden: true,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Senhas não coincidem';
                      }
                      return null;
                    },
                  ),
                ],
                if (!widget.isSignUp) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/reset-password'),
                      child: const Text('Esqueceu a senha?'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final isLoading = state.status == AuthStatus.loading;
                    return DsPrimaryButton(
                      onPressed: isLoading ? null : _handleSubmit,
                      label: widget.isSignUp ? 'Criar conta' : 'Entrar',
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.isSignUp ? 'Já tem uma conta? ' : 'Não tem uma conta? '),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          // Alterna entre sign up e sign in
                        });
                        context.replace(
                          widget.isSignUp ? '/auth/signin' : '/auth/signup',
                        );
                      },
                      child: Text(widget.isSignUp ? 'Entrar' : 'Criar conta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isSignUp) {
      context.read<AuthCubit>().signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
    } else {
      context.read<AuthCubit>().signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }
}

