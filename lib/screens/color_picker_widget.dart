import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerWidget extends StatefulWidget {
  final Function(Color) onColorSelected;

  ColorPickerWidget({required this.onColorSelected});

  @override
  _ColorPickerWidgetState createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  Color _selectedColor = Colors.black;

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("色を選択"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text("決定"),
            onPressed: () {
              widget.onColorSelected(_selectedColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openColorPicker,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _selectedColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Icon(Icons.color_lens, color: Colors.white),
      ),
    );
  }
}
