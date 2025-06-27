import 'package:flutter/material.dart';

class BtnVCustomButton extends StatelessWidget {
  final String vaText;
  final VoidCallback vaOnPressed;

  const BtnVCustomButton({
    super.key,
    required this.vaText,
    required this.vaOnPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vaOnPressed,
        child: Text(vaText),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
