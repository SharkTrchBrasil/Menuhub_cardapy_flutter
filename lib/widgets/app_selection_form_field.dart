import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/helpers/app_list_controller.dart';

import 'app_page_status_builder.dart';


// Interface que garante que qualquer objeto usado aqui tenha um 'title'
abstract interface class SelectableItem {
  String get title;
}

// =======================================================================
// O WIDGET DE CAMPO DE FORMULÁRIO (O que você usa na tela)
// =======================================================================
class AppSelectionFormField<T extends SelectableItem> extends StatelessWidget {
  const AppSelectionFormField({
    super.key,
    required this.title,
    required this.fetch,
    this.validator,
    required this.onChanged,
    this.initialValue,
    this.isEnabled = true,
  });

  final String title;
  final Future<Either<void, List<T>>> Function() fetch;
  final String? Function(T?)? validator;
  final Function(T?) onChanged;
  final T? initialValue;
  final bool isEnabled;

  Future<void> showSelectionDialog(
      BuildContext context,
      FormFieldState<T> state,
      ) async {
    if (!isEnabled) return;

    final item = await showDialog<T>(
      context: context,
      builder: (_) => AppSelectionDialog<T>(fetch: fetch, title: title),
    );
    if (item != null) {
      state.didChange(item);
      onChanged(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: initialValue,
      validator: validator,
      enabled: isEnabled,
      builder: (state) {
        return InkWell(
          onTap: () => showSelectionDialog(context, state),
          borderRadius: BorderRadius.circular(8.0),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: state.value != null
                  ? IconButton(
                tooltip: 'Limpar seleção',
                icon: const Icon(Icons.close),
                onPressed: isEnabled
                    ? () {
                  state.didChange(null);
                  onChanged(null);
                }
                    : null,
              )
                  : const Icon(Icons.keyboard_arrow_down),
            ),
            isEmpty: state.value == null,
            child: state.value == null
                ? const SizedBox(height: 24)
                : Text(
              state.value!.title,
              style: TextStyle(
                fontSize: 16,
                color: isEnabled ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}

// =======================================================================
// O DIALOG DE SELEÇÃO (O que abre ao clicar)
// =======================================================================
class AppSelectionDialog<T extends SelectableItem> extends StatelessWidget {
  AppSelectionDialog({super.key, required this.fetch, required this.title});

  final Future<Either<void, List<T>>> Function() fetch;
  final String title;
  late final AppListController<T> listController = AppListController<T>(fetch: fetch);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          maxWidth: 500,
        ),
        child: AnimatedBuilder(
          animation: listController,
          builder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selecione um(a) $title',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      CloseButton(onPressed: () => context.pop()),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: AppPageStatusBuilder<List<T>>(
                    status: listController.status,
                    tryAgain: listController.refresh,
                    successBuilder: (items) {
                      if (items.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Nenhum item encontrado.')));
                      }
                      // ✅ AQUI ESTÁ A MUDANÇA: Usamos ListView e ListTile
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(item.title),
                            onTap: () {
                              context.pop(item);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}