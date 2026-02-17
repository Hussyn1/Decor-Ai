import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildSearchBar(),
            const SizedBox(height: 32),
            _buildSectionHeader('Featured Designs'),
            const SizedBox(height: 16),
            _buildFeaturedCarousel(),
            const SizedBox(height: 32),
            _buildSectionHeader('Trending Categories'),
            const SizedBox(height: 16),
            _buildCategoriesGrid(),
            const SizedBox(height: 32),
            _buildSectionHeader('Community Inspiration'),
            const SizedBox(height: 16),
            _buildCommunityGird(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search for furniture, styles...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('See All'),
        ),
      ],
    );
  }

  Widget _buildFeaturedCarousel() {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFeaturedItem(
            'Minimalist Nordic',
            'By Sarah K.',
            'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?q=80&w=2158',
          ),
          const SizedBox(width: 16),
          _buildFeaturedItem(
            'Industrial Loft',
            'By Marco V.',
            'https://images.unsplash.com/photo-1560448204-61dc36dc98c8?q=80&w=2070',
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedItem(String title, String author, String imageUrl) {
    return Container(
      width: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Image.network(imageUrl, fit: BoxFit.cover, height: double.infinity, width: double.infinity),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  author,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildCategoryItem('Modern', Icons.chair, Colors.blue),
        _buildCategoryItem('Vintage', Icons.history, Colors.orange),
        _buildCategoryItem('Minimal', Icons.check_circle_outline, Colors.green),
        _buildCategoryItem('Luxury', Icons.diamond, Colors.purple),
      ],
    );
  }

  Widget _buildCategoryItem(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityGird() {
    return MasonryGrid(
      children: [
        _buildInspirationItem('https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?q=80&w=2071'),
        _buildInspirationItem('https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?q=80&w=2064'),
        _buildInspirationItem('https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?q=80&w=2000'),
        _buildInspirationItem('https://images.unsplash.com/photo-1616137422495-1e9e46e2aa77?q=80&w=2162'),
      ],
    );
  }

  Widget _buildInspirationItem(String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Image.network(imageUrl, fit: BoxFit.cover),
    );
  }
}

class MasonryGrid extends StatelessWidget {
  final List<Widget> children;
  const MasonryGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [children[0], children[2]],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [children[1], children[3]],
          ),
        ),
      ],
    );
  }
}
