// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';

import '../../themes/classic/widgets/profile_tile.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: Center( // Centraliza o conteúdo da tela de perfil
        child: SingleChildScrollView( // Permite rolagem se o conteúdo for grande
          padding: const EdgeInsets.all(16.0),
          child: ProfilTile(), // **Aqui você reutiliza seu widget ProfilTile existente**
        ),
      ),
    );
  }
}