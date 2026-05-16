import 'package:decor_ar_fyp/screens/ar_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/three_d_generator_controller.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ThreeDGeneratorScreen extends StatelessWidget {
  const ThreeDGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ThreeDGeneratorController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Furniture Generator'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reset(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Convert Furniture Images to 3D Models',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 1. Image Selection Area & 3D Preview (Conditional)
            Obx(() {
              if (controller.glbUrl.value.isNotEmpty && !controller.isGenerating.value) {
                // SHOW 3D PREVIEW
                return Container(
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        ModelViewer(
                          key: ValueKey(controller.glbUrl.value),
                          backgroundColor: const Color(0xFFEEEEEE),
                          src: controller.glbUrl.value, 
                          alt: "3D Furniture Model",
                          ar: false,
                          autoRotate: true,
                          cameraControls: true,
                          interactionPrompt: InteractionPrompt.auto,
                          shadowIntensity: 1.0,
                          autoPlay: true,
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "3D PREVIEW",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              // SHOW IMAGE PICKER
              return controller.selectedImage.value == null
                  ? InkWell(
                      onTap: () => controller.pickImage(),
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text('Select an image from gallery'),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            controller.selectedImage.value!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.red,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: () => controller.reset(),
                            ),
                          ),
                        ),
                      ],
                    );
            }),

            // 2. Generate Button & Progress
            Obx(
              () => Column(
                children: [
                  if (controller.isGenerating.value) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: (controller.progress.value / 100).toDouble(),
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${controller.progress.value}% Complete",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          controller.selectedImage.value == null ||
                                  controller.isGenerating.value
                              ? null
                              : () => controller.generate3DModel(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: controller.isGenerating.value ? Colors.grey : null,
                      ),
                      child: controller.isGenerating.value
                          ? const Text('Generating Model...')
                          : const Text(
                              'Generate 3D Model',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Status Message & Action
            Obx(
              () => controller.statusMessage.value.isNotEmpty
                  ? Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            controller.statusMessage.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (controller.glbUrl.value.isNotEmpty && !controller.isGenerating.value) 
                          Padding(
                            padding: const EdgeInsets.only(top: 25),
                            child: SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArViewScreen(
                                        // PASS LOCAL PATH IF READY, ELSE FALLBACK TO URL
                                        initialModelUrl: controller.localGlbPath.value.isNotEmpty 
                                          ? controller.localGlbPath.value 
                                          : controller.glbUrl.value,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.view_in_ar, size: 28),
                                label: const Text('Place in Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 5,
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
      ),
    );
  }
}
