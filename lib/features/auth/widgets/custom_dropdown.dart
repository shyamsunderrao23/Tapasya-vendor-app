import 'package:flutter/material.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';

class CustomDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String label;
  final IconData icon;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor),
      elevation: 4,
      style: AppTheme.bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppTheme.blackColor,
      ),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: AppTheme.bodyStyle.copyWith(
          color: AppTheme.greyColor,
          fontSize: 15,
        ),
        floatingLabelStyle: AppTheme.bodyStyle.copyWith(
          color: AppTheme.primaryColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<String>>((String itemValue) {
        return DropdownMenuItem<String>(
          value: itemValue,
          child: Text(itemValue),
        );
      }).toList(),
    );
  }
}
