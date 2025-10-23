// ignore_for_file: deprecated_member_use, avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:provider/provider.dart';

import '../controllers/customer_controller.dart';
import '../core/di.dart';
import '../helpers/mask.dart';
import '../helpers/typography.dart';
import '../models/customer.dart';

import '../repositories/auth_repository.dart';
import '../themes/ds_theme_switcher.dart';
import 'app_primary_button.dart';
import 'app_text_field.dart';



class AppBarCode extends StatefulWidget implements PreferredSizeWidget {
const AppBarCode({super.key});

@override
State<AppBarCode> createState() => _AppBarCodeState();

@override
Size get preferredSize => const Size.fromHeight(kToolbarHeight); // Ajuste este valor se necessário
}

class _AppBarCodeState extends State<AppBarCode> {


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Determina se é um layout de telefone ou não
      bool isPhone = constraints.maxWidth < 800;
      double appBarHeight = isPhone ? kToolbarHeight : 115; // Altura da AppBar

      return PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: _buildAppBar(isPhone: isPhone, size: constraints.maxWidth),
      );
    });
  }

  Widget _buildAppBar({required bool isPhone, required double size}) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final customerController = getIt<CustomerController>(); // Obtém o controller via getIt
    // final authRepository = getIt<AuthRepository>(); // Não diretamente usado aqui

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: isPhone ? kToolbarHeight : 115,
      backgroundColor: theme.backgroundColor,
      elevation: 0,
      actions: [
        // Dummy Search/Language (mantido como está, sem lógica)
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
              ),
              width: isPhone ? 50 : 150,
            ),
          ],
        ),
        isPhone ? const SizedBox(width: 10) : const SizedBox(),

        // Ícone do Carrinho (notification)
        Container(
          height: 42,
          width: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Theme(
            data: ThemeData(
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                dialogBackgroundColor: theme.sidebarBackgroundColor),
            child: PopupMenuButton(
              onOpened: () {

              },
              onCanceled: () {

              },
              constraints: const BoxConstraints(
                maxWidth: 396,
                minWidth: 396,
              ),
              tooltip: "",
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: theme.cardColor,
              offset: Offset(50, isPhone ? 55 : 80),
              icon: Center(
                  child: Image.asset("assets/images/shopping-bagcartcart.png",
                      height: 28, width: 28, color: theme.primaryColor)),
              itemBuilder: (ctx) => [
                // Aqui você usaria a CartArea
                PopupMenuItem(
                  enabled: false, // Para evitar que o clique no item feche o menu
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: isPhone ? 420 : 700,
                    width: 396,

                  ),
                ),
              ],
            ),
          ),
        ),

        // Ícone de Perfil / Login (Account)
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
              ),
              width: isPhone ? 50 : 165,
            ),
            PopupMenuButton(
              onOpened: () {

              },
              onCanceled: () {

              },
              color: theme.cardColor, // Usa a cor do tema
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              offset: Offset(10, isPhone ? 55 : 85),
              constraints: BoxConstraints(
                  minHeight: size < 600 ? 500 : 450,
                  maxHeight: size < 600 ? 500 : 450,
                  maxWidth: 280,
                  minWidth: 280),
              tooltip: "",
              itemBuilder: (ctx) => [
                // AQUI É ONDE INTEGRAMOS O ProfilTile
                PopupMenuItem(
                  enabled: false, // Para evitar que o clique no item feche o menu
                  padding: EdgeInsets.zero, // Remove padding extra do PopupMenuItem
                  child: SizedBox(
                    width: 350, // Largura fixa ou responsiva conforme seu layout
                    child: ProfilTile(), // SEU WIDGET ProfilTile
                  ),
                ),
              ],
              padding: EdgeInsets.zero, // Remove padding extra do PopupMenuButton
              child: isPhone
                  ? ValueListenableBuilder<Customer?>(
                valueListenable: customerController,
                builder: (context, customer, _) {
                  return CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.transparent,
                    backgroundImage: customer != null && customer.photo != null && customer.photo!.isNotEmpty
                        ? NetworkImage(customer.photo!)
                        : const AssetImage("assets/images/05.png") as ImageProvider,
                  );
                },
              )
                  : Container(
                width: 180,
                color: Colors.transparent,
                child: Center(
                  child: ValueListenableBuilder<Customer?>(
                    valueListenable: customerController,
                    builder: (context, customer, _) {
                      return ListTile(
                        onTap: null, // A ação de abrir o menu já é do PopupMenuButton

                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.transparent,
                          backgroundImage: customer != null && customer.photo != null && customer.photo!.isNotEmpty
                              ? NetworkImage(customer.photo!)
                              : const AssetImage("assets/images/05.png") as ImageProvider,
                        ),
                        title: Text(
                          customer?.name ?? 'Minha Conta', // Nome do cliente ou 'Minha Conta'
                          style: Typographyy.bodyLargeMedium.copyWith(color: theme.sidebarTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  PopupMenuItem notification({required bool isphon}) {
    return PopupMenuItem(
      enabled: false,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: isphon ?  420 : 700,
        width: 396,

      ),
    );
  }
}




// --- SEU WIDGET ProfilTile ORIGINAL (MODIFICADO) ---

class ProfilTile extends StatefulWidget {
  const ProfilTile({super.key});

  @override
  State<ProfilTile> createState() => _ProfilTileState();
}

class _ProfilTileState extends State<ProfilTile> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Novo método para exibir o diálogo genérico
  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerController = getIt<CustomerController>();
    final authRepository = getIt<AuthRepository>();


    return ValueListenableBuilder<Customer?>(
      valueListenable: customerController,
      builder: (context, customer, _) {


        final theme = context
            .watch<DsThemeSwitcher>()
            .theme;

        if (customer == null) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Entre para acessar suas informações',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                  //  color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  icon: Image.asset(
                    'assets/images/google.png',
                    height: 24,
                  ),
                  label: const Text('Entrar com o Google'),

                  onPressed: () async {


                    Navigator.of(context).pop();
                    final user = await _signInWithGoogle();
                    if (user != null) {
                      await authRepository.signInAndSaveCustomerWithGoogle(
                        user.displayName,
                        user.email,
                        user.photoURL,

                      );
                      // Aguardar a atualização do controller
                      // É crucial que o customerController já esteja atualizado aqui.
                      final updatedCustomer = getIt<CustomerController>().value;

                      // **Somente aqui, após o login, verifica se o telefone está vazio e mostra o diálogo.**
                      if (updatedCustomer?.phone == null ||
                          updatedCustomer!.phone!.isEmpty) {
                        // Certifica-se de que o diálogo é exibido apenas uma vez após o login
                        // e se o telefone ainda estiver vazio.
                        _showPhoneDialog(context, updatedCustomer);
                      }
                    }
                  },
                ),
              ],
            ),
          );
        }


        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    customer.photo ?? 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/User-avatar.svg/2048px-User-avatar.svg.png',
                  ),
                ),
                title: Text(
                  customer.name,
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.onBackgroundColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  customer.email,
                  style: Typographyy.bodySmallMedium.copyWith(
                    color: theme.onBackgroundColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Divider(color: theme.onBackgroundColor.withOpacity(0.2)),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.location_on,
                  color: theme.onBackgroundColor.withOpacity(0.7),
                ),
                title: Text(
                  'Meus Endereços',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.onBackgroundColor,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Fecha o popup
                  _showInfoDialog(
                    context,
                    'Meus Endereços',
                    'Aqui você verá seus endereços cadastrados.',
                  );
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.receipt_long,
                  color: theme.onBackgroundColor.withOpacity(0.7),
                ),
                title: Text(
                  'Meus Pedidos',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.onBackgroundColor,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Fecha o popup
                  _showInfoDialog(
                    context,
                    'Meus Pedidos',
                    'Aqui você verá seu histórico de pedidos.',
                  );
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.phone,
                  color: theme.onBackgroundColor.withOpacity(0.7),
                ),
                title: Text(
                  'Telefone',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.onBackgroundColor,
                  ),
                ),
                subtitle: Text(
                  customer.phone != null && customer.phone!.isNotEmpty
                      ? customer.phone!
                      : 'Adicionar telefone',
                  style: Typographyy.bodySmallMedium.copyWith(
                    color: theme.onBackgroundColor.withOpacity(0.7),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Fecha o popup
                  _showPhoneDialog(context, customer);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.settings,
                  color: theme.onBackgroundColor.withOpacity(0.7),
                ),
                title: Text(
                  'Configurações da conta',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.onBackgroundColor,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Fecha o popup
                  _showInfoDialog(
                    context,
                    'Configurações',
                    'Página de configurações da conta.',
                  );
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.logout, color: theme.primaryColor),
                title: Text(
                  'Sair',
                  style: Typographyy.bodyMediumSemiBold.copyWith(
                    color: theme.primaryColor,
                  ),
                ),
                onTap: () {
               //   authRepository.signOut();
                  Navigator.of(context).pop(); // Fecha o popup
                },
              ),
            ],
          ),
        );
      },


    );

  }

  Future<User?> _signInWithGoogle() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    GoogleAuthProvider authProvider = GoogleAuthProvider();
    try {
      final UserCredential userCredential =
      await auth.signInWithPopup(authProvider);
      return userCredential.user;
    } catch (e) {
      print('Erro ao logar com Google: $e');
      return null;
    }
  }


  void _showPhoneDialog(BuildContext context, Customer? customer) {
    final TextEditingController phoneController = TextEditingController();
    if (customer?.phone != null && customer!.phone!.isNotEmpty) {
      phoneController.text = customer.phone!;
    }

    final isMobile = MediaQuery
        .of(context)
        .size
        .width < 600;
    final buttonPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)
        : const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            backgroundColor: Theme
                .of(context)
                .scaffoldBackgroundColor,
            insetPadding: EdgeInsets.symmetric(
              horizontal: MediaQuery
                  .of(context)
                  .size
                  .width < 600 ? 10 : 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            actionsPadding:
            const EdgeInsets.only(top: 0, left: 8, right: 8, bottom: 5),
            title: const Text(
              'Adicionar Whatsapp/Telefone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              height: 150,
              child: Center(
                child: AppTextField(
                  controller: phoneController,
                  title: '',
                  hint: 'Digite seu whatsapp',
                  validator: (s) {
                    if (s == null || s
                        .trim()
                        .isEmpty) {
                      return 'Campo obrigatório';
                    }
                    try {
                      final phone =
                      PhoneNumber.parse(s, destinationCountry: IsoCode.BR);
                      final isValidMobile = phone.isValid(
                          type: PhoneNumberType.mobile);
                      if (!isValidMobile) {
                        return 'Número de celular inválido';
                      }
                      return null;
                    } catch (e) {
                      return 'Número inválido';
                    }
                  },
                  formatters: [phoneMask],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Padding(
                padding: buttonPadding,
                child: SizedBox(
                  width: MediaQuery
                      .of(context)
                      .size
                      .width < 600 ? 120 : 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          onPressed: () async {
                            final phone = phoneController.text.trim();
                            if (phone.isNotEmpty) {
                              Navigator.of(context).pop();

                              final current = getIt<CustomerController>().value;
                              getIt<CustomerController>()
                                  .setCustomer(current!.copyWith(phone: phone));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Por favor, digite seu número de telefone.')),
                              );
                            }
                          },
                          label: 'Salvar',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }


}