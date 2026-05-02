import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_state.dart';

class PhotoGridItem extends StatelessWidget {
  final PhotoItem photo;
  final VoidCallback? onTap;

  const PhotoGridItem({super.key, required this.photo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEDE9FF),
                child: const Icon(Icons.photo, color: Color(0xFFB39DFF)),
              ),
            ),
            if (photo.isFavorite)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite,
                      color: Colors.pinkAccent, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
