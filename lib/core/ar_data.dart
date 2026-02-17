import 'package:flutter/material.dart';

class ArData {
  ArData._();

  static const List<Map<String, dynamic>> materialSwatches = [
    {'name': 'Default', 'color': Colors.white, 'texture': null},
    {
      'name': 'Velvet Blue',
      'color': Color(0xFF1565C0),
      'texture':
          'https://images.unsplash.com/photo-1544433373-219669527e02?q=80&w=100',
    },
    {
      'name': 'Leather Brown',
      'color': Color(0xFF5D4037),
      'texture':
          'https://images.unsplash.com/photo-1598440445582-736006422894?q=80&w=100',
    },
    {
      'name': 'Dark Slate',
      'color': Color(0xFF37474F),
      'texture':
          'https://images.unsplash.com/photo-1541701494587-cb58502866ab?q=80&w=100',
    },
    {
      'name': 'Brushed Steel',
      'color': Colors.grey,
      'texture':
          'https://images.unsplash.com/photo-1558484666-ac33390f7015?q=80&w=100',
    },
  ];

  static const List<Map<String, dynamic>> furniture = [
    {
      'id': 'f1',
      'name': 'Sheen Chair',
      'price': 299.0,
      'price_display': '\$299',
      'image':
          'https://images.unsplash.com/photo-1592078615290-033ee584e267?q=80&w=1964',
      'model':
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/SheenChair/glTF-Binary/SheenChair.glb',
      'scale': 1.0,
      'style': 'Minimalist',
      'color': 'Grey',
      'dims': [0.6, 0.8, 0.6],
    },
    {
      'id': 'f2',
      'name': 'Decorative Lantern',
      'price': 85.0,
      'price_display': '\$85',
      'image':
          'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?q=80&w=2070',
      'model':
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Lantern/glTF-Binary/Lantern.glb',
      'scale': 1.0,
      'style': 'Industrial',
      'color': 'Black',
      'dims': [0.3, 0.5, 0.3],
    },
    {
      'id': 'f3',
      'name': 'Classic Duck',
      'price': 15.0,
      'price_display': '\$15',
      'image':
          'https://images.unsplash.com/photo-1586023492125-27b2c0450d81?q=80&w=1000',
      'model':
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb',
      'scale': 1.0,
      'style': 'Boutique',
      'color': 'Yellow',
      'dims': [0.2, 0.2, 0.2],
    },
  ];
}
