import 'package:flutter/material.dart';
import 'package:totem/core/extensions.dart';
import '../helpers/constants.dart';

class SelectionButtonData {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final int? totalNotif;

  SelectionButtonData({
    required this.activeIcon,
    required this.icon,
    required this.label,
    this.totalNotif,
  });
}

class SelectionButton extends StatefulWidget {
  const SelectionButton({
    this.initialSelected = 0,
    required this.data,
    required this.onSelected,
    required this.title,
    this.selectedTextColor,
    this.unselectedTextColor,
    Key? key,
  }) : super(key: key);

  final int initialSelected;
  final String title;
  final List<SelectionButtonData> data;
  final Function(int index, SelectionButtonData value) onSelected;

  final Color? selectedTextColor;
  final Color? unselectedTextColor;

  @override
  State<SelectionButton> createState() => _SelectionButtonState();
}

class _SelectionButtonState extends State<SelectionButton> {
  late int selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 30.0),
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              letterSpacing: .8,
              fontSize: 12,
            ),
          ),
        ),
        Column(
          children: widget.data.asMap().entries.map((e) {
            final index = e.key;
            final data = e.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _Button(
                selected: selected == index,
                onPressed: () async {
                  widget.onSelected(index, data);
                  setState(() {
                    selected = index;
                  });
                },
                data: data,
                selectedTextColor: widget.selectedTextColor,
                unselectedTextColor: widget.unselectedTextColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.selected,
    required this.data,
    required this.onPressed,
    this.selectedTextColor,
    this.unselectedTextColor,
    Key? key,
  }) : super(key: key);

  final bool selected;
  final SelectionButtonData data;
  final Function() onPressed;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(kSpacing),
        child: Column(
          children: [
            Row(
              children: [
                _icon((!selected) ? data.icon : data.activeIcon, context),
                const SizedBox(width: kSpacing / 2),
                Expanded(child: _labelText(data.label, context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(IconData iconData, BuildContext context) {
    return Icon(
      iconData,
      size: 20,
      color: context.dsTheme.sidebarIconColor,
      // Você pode definir cor aqui, se desejar
    );
  }

  Widget _labelText(String data, BuildContext context) {
    final color = selected
        ? (selectedTextColor ?? Theme.of(context).primaryColor)
        : (unselectedTextColor ?? Colors.black87);

    return Text(
      data,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: .8,
        fontSize: 14,
      ),
    );
  }
}
