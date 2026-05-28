import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReimagineViewerScreen extends StatefulWidget {
  final File originalImage;
  final String generatedImageUrl;
  final String style;

  const ReimagineViewerScreen({
    super.key,
    required this.originalImage,
    required this.generatedImageUrl,
    required this.style,
  });

  @override
  State<ReimagineViewerScreen> createState() => _ReimagineViewerScreenState();
}

class _ReimagineViewerScreenState extends State<ReimagineViewerScreen> {
  double _sliderValue = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The AI Generated Image (Bottom Layer)
          Positioned.fill(
            child: _buildGeneratedImage(widget.generatedImageUrl),
          ),

          // The Original Image (Top Layer, Clipped)
          Positioned.fill(
            child: ClipRect(
              clipper: _BeforeAfterClipper(_sliderValue),
              child: Image.file(
                widget.originalImage,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // The Slider UI
          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _sliderValue += details.primaryDelta! / MediaQuery.of(context).size.width;
                  _sliderValue = _sliderValue.clamp(0.0, 1.0);
                });
              },
              child: Stack(
                children: [
                  // Divider Line
                  Positioned(
                    left: MediaQuery.of(context).size.width * _sliderValue - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white,
                    ),
                  ),
                  // Drag Handle
                  Positioned(
                    left: MediaQuery.of(context).size.width * _sliderValue - 20,
                    top: MediaQuery.of(context).size.height / 2 - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.unfold_more_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Header
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.style,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Labels
          Positioned(
            bottom: 60,
            left: 20,
            child: const Text(
              'BEFORE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
            ),
          ),
          Positioned(
            bottom: 60,
            right: 20,
            child: const Text(
              'AFTER',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the AI-generated image from either a local file path or a URL.
  Widget _buildGeneratedImage(String source) {
    // HF API returns a local file path; Pollinations returns a URL
    if (source.startsWith('/') ||
        source.startsWith('file://') ||
        source.contains('\\')) {
      return Image.file(
        File(source.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 48),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.error, color: Colors.white, size: 48),
      ),
    );
  }
}

class _BeforeAfterClipper extends CustomClipper<Rect> {
  final double sliderValue;

  _BeforeAfterClipper(this.sliderValue);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * sliderValue, size.height);
  }

  @override
  bool shouldReclip(_BeforeAfterClipper oldClipper) => oldClipper.sliderValue != sliderValue;
}
