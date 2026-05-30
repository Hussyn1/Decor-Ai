import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Help Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFaqItem('How do I measure a room?', 'Go to Home > Quick Tools > AR Measure. Point your camera at the floor and follow the instructions.'),
          _buildFaqItem('How does 2D to 3D work?', 'Upload a sketch or photo of a furniture item. Our AI will process it and create a 3D model you can place in your room.'),
          _buildFaqItem('Can I save my designs?', 'Yes, all projects are automatically saved and synced to your account.'),
          const SizedBox(height: 32),
          const Text('Need more help?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'support@decorai.com',
                query: 'subject=Decor%20AI%20Support%20Request',
              );
              try {
                if (await canLaunchUrl(emailLaunchUri)) {
                  await launchUrl(emailLaunchUri);
                } else {
                  Get.snackbar(
                    'Error',
                    'Could not launch email client.',
                    backgroundColor: Colors.red.shade100,
                    colorText: Colors.red.shade900,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to open email client: $e',
                  backgroundColor: Colors.red.shade100,
                  colorText: Colors.red.shade900,
                );
              }
            },
            icon: const Icon(Icons.email_outlined),
            label: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('About Decor AI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Decor AI',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text('Version 1.0.0 (FYP Build)', style: TextStyle(color: AppTheme.textGrey)),
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Decor AI is an advanced interior design platform leveraging AR and AI to help you visualize and create your dream space. Built as a Final Year Project.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const Spacer(),
            const Text('Developed with ❤️ by Your Name', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
