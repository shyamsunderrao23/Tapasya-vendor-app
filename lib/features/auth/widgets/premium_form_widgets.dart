import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tapasya_vendor_app/core/theme/app_theme.dart';

class PremiumFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const PremiumFieldLabel({
    super.key,
    required this.label,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle.copyWith(
              color: const Color(0xFF374151), // Cool grey 700
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (isRequired)
            const Text(
              " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}

class PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final IconData? suffixIcon;
  final Widget? suffix;
  final bool isRequired;
  final bool readOnly;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final int maxLines;
  final int? maxLength;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.suffixIcon,
    this.suffix,
    this.isRequired = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the label text with optional star
    final String fullLabel = widget.isRequired ? "${widget.label} *" : widget.label;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      style: AppTheme.bodyStyle.copyWith(
        color: AppTheme.blackColor,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: fullLabel,
        labelStyle: TextStyle(
          color: _focusNode.hasFocus ? AppTheme.primaryColor : const Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: widget.hint,
        hintStyle: AppTheme.bodyStyle.copyWith(color: const Color(0xFF9CA3AF), fontSize: 14),
        counterText: widget.maxLength != null ? null : "",
        prefixIcon: widget.icon != null 
          ? Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(widget.icon, color: AppTheme.primaryColor, size: 20),
            ) 
          : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.suffix ?? (widget.suffixIcon != null 
          ? Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(widget.suffixIcon, color: const Color(0xFF6B7280), size: 20),
            )
          : null),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: widget.readOnly ? const Color(0xFFF9FAFB) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}

class PremiumDatePicker extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isRequired;
  final Function(DateTime) onDateSelected;

  const PremiumDatePicker({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.isRequired = false,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumTextField(
      controller: controller,
      label: label,
      hint: hint,
      isRequired: isRequired,
      readOnly: true,
      suffixIcon: Icons.calendar_month_rounded,
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  onSurface: AppTheme.blackColor,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
    );
  }
}

class PremiumDropdownField extends StatelessWidget {
  final String? value;
  final String label;
  final String? hint;
  final List<String> items;
  final bool isRequired;
  final Function(String) onChanged;
  final String? Function(String?)? validator;

  const PremiumDropdownField({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    required this.items,
    this.isRequired = false,
    required this.onChanged,
    this.validator,
  });

  void _showSelectionSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Select $label", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B263B))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == value;
                    return InkWell(
                      onTap: () {
                        onChanged(item);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFF1B263B),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic).fadeIn();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullLabel = isRequired ? "$label *" : label;

    return GestureDetector(
      onTap: () => _showSelectionSheet(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: fullLabel,
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // Match PremiumTextField
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint ?? "Select $label",
                style: TextStyle(
                  color: value != null ? const Color(0xFF1B263B) : const Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

class PremiumMultiSelectField extends StatefulWidget {
  final List<String> selectedItems;
  final String label;
  final String hint;
  final List<String> options;
  final bool isRequired;
  final Function(List<String>) onChanged;

  const PremiumMultiSelectField({
    super.key,
    required this.selectedItems,
    required this.label,
    required this.hint,
    required this.options,
    this.isRequired = false,
    required this.onChanged,
  });

  @override
  State<PremiumMultiSelectField> createState() => _PremiumMultiSelectFieldState();
}

class _PremiumMultiSelectFieldState extends State<PremiumMultiSelectField> {
  void _showSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<String> tempSelected = List<String>.from(widget.selectedItems);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Select ${widget.label}", style: AppTheme.subHeadingStyle.copyWith(fontSize: 18)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.options.length,
                      itemBuilder: (context, index) {
                        final option = widget.options[index];
                        final isChecked = tempSelected.contains(option);
                        return CheckboxListTile(
                          title: Text(option, style: AppTheme.bodyStyle.copyWith(fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal)),
                          value: isChecked,
                          activeColor: AppTheme.primaryColor,
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                tempSelected.add(option);
                              } else {
                                tempSelected.remove(option);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: GestureDetector(
                      onTap: () {
                        widget.onChanged(tempSelected);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(28)),
                        child: const Center(child: Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullLabel = widget.isRequired ? "${widget.label} *" : widget.label;

    return GestureDetector(
      onTap: _showSelectionBottomSheet,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: fullLabel,
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        child: widget.selectedItems.isEmpty
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.hint, style: AppTheme.bodyStyle.copyWith(color: const Color(0xFF9CA3AF))),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                ],
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.selectedItems.map((item) {
                  return IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              final newList = List<String>.from(widget.selectedItems)..remove(item);
                              widget.onChanged(newList);
                            },
                            child: const Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}
