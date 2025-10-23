import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/store.dart';
import '../themes/ds_theme.dart';



class FooterWidget extends StatelessWidget {
  final Store? store;
  final DsTheme theme;

  const FooterWidget({Key? key, this.store, required this.theme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(24),
      color: theme.secondaryColor, // Cor de fundo do footer
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store?.name ?? 'Nome da Loja',

          ),
          const SizedBox(height: 12),
          Text(
            store?.name ?? 'Endereço da Loja, Cidade - Estado',
            style: theme.bodyTextStyle.colored(theme.onSecondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Telefone: ${store?.phone ?? '(XX) XXXX-XXXX'}',
            style: theme.bodyTextStyle.colored(theme.onSecondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Email: ${store?.facebook ?? 'contato@loja.com'}',
            style: theme.bodyTextStyle.colored(theme.onSecondaryColor),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.facebook, color: theme.onSecondaryColor),
                onPressed: () {
                  // Lógica para abrir link do Facebook
                },
              ),
              IconButton(
                icon: Icon(Icons.camera_alt, color: theme.onSecondaryColor),
                onPressed: () {
                  // Lógica para abrir link do Instagram
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© ${DateTime.now().year} ${store?.name ?? 'Sua Loja'}. Todos os direitos reservados.',

              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}