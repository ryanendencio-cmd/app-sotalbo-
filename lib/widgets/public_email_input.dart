import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const publicEmailDomains = <String, String>{
  'Gmail': 'gmail.com',
  'Yahoo Mail': 'yahoo.com',
  'Outlook': 'outlook.com',
  'Hotmail': 'hotmail.com',
  'iCloud Mail': 'icloud.com',
  'Proton Mail': 'proton.me',
  'Zoho Mail': 'zohomail.com',
  'GMX Mail': 'gmx.com',
  'AOL Mail': 'aol.com',
  'Yandex Mail': 'yandex.com',
};

class PublicEmailInput extends StatelessWidget {
  final TextEditingController controller;
  final String domain;
  final ValueChanged<String> onDomainChanged;
  final ValueChanged<String>? onChanged;
  final bool requiredField;

  const PublicEmailInput({
    super.key,
    required this.controller,
    required this.domain,
    required this.onDomainChanged,
    this.onChanged,
    this.requiredField = false,
  });

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) {
      return requiredField ? 'Email address is required' : null;
    }
    if (!RegExp(r'^[A-Za-z0-9._+-]+$').hasMatch(username) ||
        username.startsWith('.') ||
        username.endsWith('.') ||
        username.contains('..')) {
      return 'Enter only the email username (before @)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredField ? 'Email Address' : 'Email Address (Optional)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: onChanged,
                  validator: _validateUsername,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Email username',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    errorStyle: GoogleFonts.inter(fontSize: 10, height: 1),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFA63228),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 142,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(domain),
                  initialValue: domain,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFA63228),
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  items: publicEmailDomains.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.value,
                          child: Text(
                            '@${entry.value}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onDomainChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
