import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

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
      height: 100,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4)),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: furniture.length,
            itemBuilder: (context, index) {
              return SizedBox(width: 140, child: _buildFurnitureItem(index));
            },
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
              child: CachedNetworkImage(
                imageUrl: item['image'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[600]!,
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[800],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 24,
                  ),
                ),
              ),
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
}
