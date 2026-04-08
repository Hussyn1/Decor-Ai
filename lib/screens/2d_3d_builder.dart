import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../controllers/three_d_generator_controller.dart';
import '../core/app_theme.dart';
import 'model_viewer_screen.dart';
import 'ar_view_screen.dart';

class TwoDToThreeDBuilder extends StatefulWidget {
  const TwoDToThreeDBuilder({super.key});

  @override
  State<TwoDToThreeDBuilder> createState() => _TwoDToThreeDBuilderState();
}

class _TwoDToThreeDBuilderState extends State<TwoDToThreeDBuilder>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  final controller = Get.put(ThreeDGeneratorController());

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // 4 steps × 2s each
    );

    // Sync animation with GetX controller state
    ever(controller.isGenerating, (bool isGenerating) {
      if (isGenerating) {
        _progressController.forward(from: 0.0);
      } else {
        if (controller.glbUrl.value.isNotEmpty) {
          _progressController.animateTo(
            1.0,
            duration: const Duration(milliseconds: 500),
          );
        } else {
          _progressController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '2D to 3D Furniture',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reset(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUploadSection(controller),
            _buildPreviewSection(controller),
            _buildControlsSection(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection(ThreeDGeneratorController controller) {
    return Container(
      width: double.infinity,
      height: 250,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.grey.shade50),
      child: GestureDetector(
        onTap: () => controller.pickImage(),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Obx(
            () => controller.selectedImage.value != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        controller.selectedImage.value!,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.1),
                        child: const Center(
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_rounded,
                          color: AppTheme.primaryBlue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Upload Furniture Sketch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to pick an image from gallery',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ThreeDGeneratorController controller) {
    return Container(
      width: double.infinity,
      height: 350,
      color: const Color(0xFF0F1115),
      child: Obx(() {
        final isGenerating = controller.isGenerating.value;
        final hasModel = controller.glbUrl.value.isNotEmpty;

        // STATE 1: Model is ready — show interactive 3D viewer
        if (hasModel && !isGenerating) {
          return Stack(
            children: [
              // Interactive 3D model viewer
              ModelViewer(
                src: controller.glbUrl.value,
                alt: '3D furniture model',
                ar: false,
                autoRotate: true,
                cameraControls: true,
                backgroundColor: const Color(0xFF0F1115),
                autoRotateDelay: 0,
              ),

              // Label
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '3D MODEL READY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),

              // Fullscreen button
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ModelViewerScreen(glbUrl: controller.glbUrl.value),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // STATE 2: Generating or idle — show animated placeholder
        return Stack(
          children: [
            const RepaintBoundary(
              child: CustomPaint(
                painter: DotPatternPainter(),
                child: SizedBox.expand(),
              ),
            ),

            Center(
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  double progress = _progressController.value;

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateX(-0.4)
                      ..rotateY(isGenerating ? (progress * 0.2) : 0),
                    alignment: FractionalOffset.center,
                    child: Container(
                      width: 280,
                      height: 180,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(
                            isGenerating ? 0.8 : 0.2,
                          ),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                      ),
                      child: Stack(
                        children: [
                          // Liquid fill effect during generation
                          if (isGenerating)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                height: 180 * progress,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppTheme.primaryBlue.withOpacity(0.6),
                                      AppTheme.primaryBlue.withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  color: isGenerating
                                      ? Colors.white
                                      : AppTheme.primaryBlue.withOpacity(0.5),
                                  size: 56,
                                ),
                                if (isGenerating) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'GENERATING ${(progress * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Obx(
                                      () => Text(
                                        controller.generationStep.value <
                                                ThreeDGeneratorController
                                                    .generationSteps
                                                    .length
                                            ? ThreeDGeneratorController
                                                  .generationSteps[controller
                                                  .generationStep
                                                  .value]
                                            : 'Finalizing…',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              top: 20,
              left: 20,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '3D FURNITURE PREVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildControlsSection(ThreeDGeneratorController controller) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.isGenerating.value
                            ? 'AI is working...'
                            : controller.glbUrl.value.isNotEmpty
                            ? '3D Model Ready!'
                            : 'Ready to Convert',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        controller.statusMessage.value.isEmpty
                            ? 'Select an image to start'
                            : controller.statusMessage.value,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (controller.isGenerating.value)
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (controller.glbUrl.value.isNotEmpty &&
                    !controller.isGenerating.value)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successGreen,
                    size: 30,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => controller.pickImage(),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Change'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Obx(
                  () => ElevatedButton.icon(
                    onPressed:
                        controller.selectedImage.value == null ||
                            controller.isGenerating.value
                        ? null
                        : () => controller.generate3DModel(),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      controller.isGenerating.value
                          ? 'Processing...'
                          : 'Convert to 3D',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => controller.glbUrl.value.isNotEmpty
                ? Column(
                    children: [
                      // View fullscreen button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ModelViewerScreen(
                                  glbUrl: controller.glbUrl.value,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.fullscreen),
                          label: const Text('View full 3D model'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppTheme.primaryBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Place in room button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (controller.glbUrl.value.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArViewScreen(
                                    initialModelUrl: controller.glbUrl.value,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.view_in_ar,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Place in your room',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  const DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2;

    const double gap = 40;

    for (double i = 0; i < size.width; i += gap) {
      for (double j = 0; j < size.height; j += gap) {
        canvas.drawCircle(Offset(i, j), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
