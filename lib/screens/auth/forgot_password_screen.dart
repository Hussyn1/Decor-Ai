import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:get/get.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../controllers/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  final AuthController _authController = Get.find<AuthController>();

  // Page index: 0 for entering email, 1 for entering code and new password
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter your email address.',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    final success = await _authController.forgotPassword(email);
    if (success) {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  void _handleResetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    if (code.isEmpty || newPassword.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill in all fields.',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
      return;
    }

    final success = await _authController.resetPassword(email, code, newPassword);
    if (success) {
      Get.back(); // Go back to login screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // App Branding / Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppTheme.primaryBlue,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _currentStep == 0 ? 'Forgot Password?' : 'Reset Password',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentStep == 0
                          ? 'Enter your email to receive a 6-digit password reset code.'
                          : 'Enter the code sent to your email and choose a new password.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_currentStep == 0) ...[
                      CustomTextField(
                        label: 'Email Address',
                        hint: 'name@example.com',
                        prefixIcon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 40),
                      Obx(() => _authController.isLoading.value
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: 'Send Reset Code',
                              onPressed: _handleSendCode,
                            )),
                    ] else ...[
                      CustomTextField(
                        label: 'Verification Code',
                        hint: '123456',
                        prefixIcon: Icons.pin_outlined,
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        label: 'New Password',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        controller: _newPasswordController,
                      ),
                      const SizedBox(height: 40),
                      Obx(() => _authController.isLoading.value
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: 'Reset Password',
                              onPressed: _handleResetPassword,
                            )),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 0;
                            });
                          },
                          child: const Text(
                            'Resend Code / Change Email',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
