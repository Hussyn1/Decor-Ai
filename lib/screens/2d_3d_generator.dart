import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/three_d_generator_controller.dart';
import 'ar_view_screen.dart'; // Added import

class ThreeDGeneratorScreen extends StatelessWidget {
  const ThreeDGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ThreeDGeneratorController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('2D to 3D Generator'),
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

            // Image Selection Area
            Obx(
              () => controller.selectedImage.value == null
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
                            Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: Colors.grey,
                            ),
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
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                              onPressed: () => controller.reset(),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 30),

            // Generate Button
            Obx(
              () => ElevatedButton(
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
                ),
                child: controller.isGenerating.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Generate 3D Model',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Status Message
            Obx(
              () => controller.statusMessage.value.isNotEmpty
                  ? Column(
                      children: [
                        Text(
                          controller.statusMessage.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (controller.glbUrl.value.isNotEmpty &&
                            !controller
                                .isGenerating
                                .value) // Show "Place in Room" when ready
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArViewScreen(
                                      initialModelUrl: controller.glbUrl.value,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.view_in_ar),
                              label: const Text('Place in Room'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
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
