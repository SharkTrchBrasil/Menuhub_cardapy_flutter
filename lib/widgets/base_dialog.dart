import 'package:flutter/material.dart';


import 'app_primary_button.dart';

class BaseDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onSave;
  final String saveText;
  final Color? backgroundColor;

  final GlobalKey<FormState>? formKey;

  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onSave,
    required this.saveText,

    this.formKey,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final buttonPadding =
        isMobile
            ? const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ) // Padding menor para mobile
            : const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 16.0,
            ); // Padding maior para web/desktop

    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 10 : 24,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
     // titlePadding: const EdgeInsets.only(top: 16, left: 16, right: 8),
      actionsPadding: const EdgeInsets.only(
        top: 0,
        left: 8,
        right: 8,
        bottom: 5,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.blue),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: content,
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Padding(
          padding: buttonPadding,
          child: SizedBox(
            width: MediaQuery.of(context).size.width < 600 ? 300 : 350,

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    onPressed: () async {
                      if (formKey == null ||
                          formKey!.currentState!.validate()) {
                        onSave();
                      }
                    },
                    label: saveText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
