import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class WorkerPhotoPicker extends StatelessWidget {
  final String? photoData;
  final String initials;
  final ValueChanged<String?>? onChanged;
  final double radius;

  const WorkerPhotoPicker({
    super.key,
    required this.photoData,
    required this.initials,
    this.onChanged,
    this.radius = 44,
  });

  Future<void> _pickPhoto(BuildContext context) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.length > 512 * 1024) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo must be 512 KB or smaller.'),
            backgroundColor: Color(0xFFA63228),
          ),
        );
        return;
      }

      final extension = photo.name.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => null,
      };
      if (mimeType == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPG, PNG, or WebP photo.'),
            backgroundColor: Color(0xFFA63228),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      onChanged?.call('data:$mimeType;base64,${base64Encode(bytes)}');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select profile photo: $error'),
          backgroundColor: const Color(0xFFA63228),
        ),
      );
    }
  }

  ImageProvider<Object>? _imageProvider() {
    final value = photoData?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      if (value.startsWith('data:image/')) {
        final separator = value.indexOf(',');
        if (separator < 0) return null;
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      }
      if (value.startsWith('https://') || value.startsWith('http://')) {
        return NetworkImage(value);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider();
    final size = radius * 2;
    final fallback = Container(
      color: const Color(0xFFA63228).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFA63228),
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onChanged == null ? null : () => _pickPhoto(context),
              child: ClipOval(
                child: image == null
                    ? fallback
                    : Image(
                        image: image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => fallback,
                      ),
              ),
            ),
          ),
          if (onChanged != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _pickPhoto(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA63228),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (onChanged != null && image != null)
            Positioned(
              top: -4,
              left: -4,
              child: GestureDetector(
                onTap: () => onChanged?.call(null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
