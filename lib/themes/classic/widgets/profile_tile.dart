import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/di.dart';
import '../../../helpers/mask.dart';
import '../../../helpers/constants.dart';
import '../../../models/customer.dart';
import '../../../repositories/auth_repository.dart';
import '../../../controllers/customer_controller.dart';
import '../../../widgets/app_primary_button.dart';
import '../../../widgets/app_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
    final customerController = getIt<CustomerController>();
    final authRepository = getIt<AuthRepository>();


    return ValueListenableBuilder<Customer?>(
      valueListenable: customerController,
      builder: (context, customer, _) {
        // Se o cliente for nulo, mostra o botão de login
        if (customer == null) {
          return ElevatedButton.icon(
            icon: const Icon(EvaIcons.google),
            label: const Text('Entrar com Google'),


            onPressed: () async {
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
          );
        }

        // Se o cliente existe, mostra as informações do perfil
        return ListTile(
          contentPadding: const EdgeInsets.all(0),
          leading: CircleAvatar(
            backgroundImage: NetworkImage(customer.photo ?? ''),
          ),
          title: Text(
            customer.name,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            customer.email,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            customer.id.toString(),
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  void _showPhoneDialog(BuildContext context, Customer? customer) {
    final TextEditingController phoneController = TextEditingController();

    // Preenche o campo de telefone se o cliente já tiver um (para edição, por exemplo)
    if (customer?.phone != null && customer!.phone!.isNotEmpty) {
      phoneController.text = customer.phone!;
    }

    final isMobile = MediaQuery
        .of(context)
        .size
        .width < 600;
    final buttonPadding = isMobile
        ? const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ) // Padding menor para mobile
        : const EdgeInsets.symmetric(
      horizontal: 30.0,
      vertical: 16.0,
    ); // Padding maior para web/desktop

    showDialog(
      context: context,
      barrierDismissible: false,
      // Impede que o usuário feche o diálogo clicando fora
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
            actionsPadding: const EdgeInsets.only(
              top: 0,
              left: 8,
              right: 8,
              bottom: 5,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Adicionar Whatsapp/Telefone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

              ],
            ),
            content: SizedBox(
              height: 150,
              child: Center(
                child: AppTextField(
                  controller: phoneController,
                  // Passe o controller aqui
                  title: '',
                  hint: 'Digite seu whatsapp',
                  validator: (s) {
                    if (s == null || s
                        .trim()
                        .isEmpty) {
                      return 'Campo obrigatório';
                    }
                    try {
                      final phone = PhoneNumber.parse(
                          s, destinationCountry: IsoCode.BR);
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
                              Navigator.of(context)
                                  .pop(); // fecha o diálogo antes do await



                              final current = getIt<CustomerController>().value;
                              getIt<CustomerController>().setCustomer(
                                current!.copyWith(phone: phone),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
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

  Future<User?> _signInWithGoogle() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    GoogleAuthProvider authProvider = GoogleAuthProvider();
    try {
      final UserCredential userCredential = await auth.signInWithPopup(
          authProvider);
      return userCredential.user;
    } catch (e) {
      print('Erro ao logar: $e');
      return null;
    }
  }
}

