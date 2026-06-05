import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.redAccent.withOpacity(0.1) 
              : Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon, 
          color: isDestructive ? Colors.redAccent : (iconColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)), 
          size: 20
        ),
      ),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w600, 
          fontSize: 16,
          color: isDestructive ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
        )
      ),
      subtitle: subtitle != null 
          ? Text(subtitle!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)) 
          : null,
      trailing: isDestructive 
          ? null 
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }
}
