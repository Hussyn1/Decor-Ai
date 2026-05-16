import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';

/// Furniture Carousel Widget
///
/// Displays a horizontal scrollable list of furniture items
/// with selection highlighting and shimmer loading effects.
class FurnitureCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> furniture;
  final int selectedIndex;
  final ValueChanged<int> onFurnitureSelected;

  const FurnitureCarousel({
    super.key,
    required this.furniture,
    required this.selectedIndex,
    required this.onFurnitureSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 110,
      child: RepaintBoundary(
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: furniture.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 140,
                    child: _buildFurnitureItem(index),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFurnitureItem(int index) {
    final item = furniture[index];
    final isSelected = index == selectedIndex;

    return GestureDetector(
      onTap: () => onFurnitureSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Furniture Image with Shimmer
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImage(item['image']),
            ),
            const SizedBox(height: 4),
            // Furniture Name
            Text(
              item['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageSource) {
    // Detect if it's a local file path
    final bool isLocalFile =
        imageSource.startsWith('/') ||
        imageSource.contains('Application Documents') ||
        imageSource.contains('com.example'); // Heuristic for local path

    if (isLocalFile) {
      return Image.file(
        File(imageSource),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageSource,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildShimmer(),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(width: 50, height: 50, color: Colors.grey[800]),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[800],
      child: const Icon(Icons.error_outline, color: Colors.white54, size: 24),
    );
  }
}
