import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';



class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.title,
    required this.hint,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.isHidden = false,
    this.icon,
    this.formatters,

    this.keyboardType,
    this.controller,
    this.readOnly = false,
    this.enabled = true,

  });

  final String title;
  final String hint;
  final String? initialValue;
  final String? Function(String?)? validator;
  final Function(String?)? onChanged;
  final bool isHidden;
  final String? icon;
  final List<TextInputFormatter>? formatters;
  final TextEditingController? controller;

  final TextInputType? keyboardType;
  final bool readOnly;
  final bool enabled;


  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool obscure = widget.isHidden;

  @override
  Widget build(BuildContext context) {


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
        overflow: TextOverflow.ellipsis,
      // style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        TextFormField(
          readOnly: widget.readOnly,
          enabled: widget.enabled,


          controller: widget.controller,
          obscureText: obscure,
          validator: widget.validator,
          initialValue: widget.initialValue,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,

          inputFormatters: widget.formatters,

          cursorColor: Colors.blue, // 🔹 Cursor azul

          decoration: InputDecoration(
            hintText: widget.hint,
           hintStyle: TextStyle(color: Colors.grey),
            isDense: true,
            isCollapsed: true, // 🔥 Remove padding interno extra
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),




            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.blue, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            suffixIcon: widget.isHidden
                ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
               // color: notifire.getGry600_500Color,
              ),
              onPressed: () {
                setState(() {
                  obscure = !obscure;
                });
              },
            )
                : widget.icon != null
                ? Padding(
              padding: const EdgeInsets.all(10.0),
              child: SvgPicture.asset(
                widget.icon!,
                width: 24,
                height: 24,
              //  color: greyscale600,
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }
}
