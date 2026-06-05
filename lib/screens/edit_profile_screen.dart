import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final user = _authController.currentUser.value;
    _nameController = TextEditingController(text: user?['username'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
    _bioController = TextEditingController(text: user?['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _authController.uploadProfilePicture(File(image.path));
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to pick image: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Personal Info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                Obx(() {
                  final user = _authController.currentUser.value;
                  final profilePic = user?['profilePicture'];
                  bool hasImage = profilePic != null && profilePic.isNotEmpty;

                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade300,
                    ),
                    child: hasImage
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profilePic,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                  );
                }),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            CustomTextField(
              label: 'Full Name',
              hint: 'Alex Thompson',
              prefixIcon: Icons.person_outline_rounded,
              controller: _nameController,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Email Address',
              hint: 'alex.t@example.com',
              prefixIcon: Icons.email_outlined,
              controller: _emailController,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Bio',
              hint: 'Interior designer & AR enthusiast',
              prefixIcon: Icons.edit_note_rounded,
              controller: _bioController,
            ),
            const SizedBox(height: 48),
            Obx(() => _authController.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : PrimaryButton(
                    text: 'Save Changes',
                    onPressed: () async {
                      final success = await _authController.updateProfile(
                        _nameController.text,
                        _emailController.text,
                        _bioController.text,
                      );
                      if (success) {
                        Get.back();
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }
}
