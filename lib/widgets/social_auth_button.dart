import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final String iconPath; // This could be an asset path or an icon for simplicity
  final IconData? icon;
  final VoidCallback onPressed;

  const SocialAuthButton({
    super.key,
    required this.text,
    this.iconPath = '',
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.grey.shade200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 20, color: Colors.black87)
            else
              const Icon(Icons.g_mobiledata, size: 24, color: Colors.black87), // Placeholder
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
