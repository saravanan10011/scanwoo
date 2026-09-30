import 'package:quick_scanner/utils/common_color.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColorConstants.grey300,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}