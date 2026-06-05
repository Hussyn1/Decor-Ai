import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/app_theme.dart';
import '../controllers/reimagine_controller.dart';

class DiscoverScreen extends StatelessWidget {
  DiscoverScreen({super.key});

  final ReimagineController _reimagineController = Get.put(
    ReimagineController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildSearchBar(context),
            const SizedBox(height: 32),
            _buildAiReimagineCard(context),
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

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
        TextButton(onPressed: () {}, child: const Text('See All')),
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
    return GestureDetector(
      onTap: () => _showReimagineWithStyleSheet(Get.context!, title, imageUrl),
      child: Container(
        width: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
            ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
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
    return _buildMasonryGrid(
      children: [
        _buildInspirationItem(
          'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?q=80&w=2071',
        ),
        _buildInspirationItem(
          'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?q=80&w=2064',
        ),
        _buildInspirationItem(
          'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?q=80&w=2000',
        ),
        _buildInspirationItem(
          'https://images.unsplash.com/photo-1616137422495-1e9e46e2aa77?q=80&w=2162',
        ),
      ],
    );
  }

  Widget _buildMasonryGrid({required List<Widget> children}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [children[0], children[2]])),
        const SizedBox(width: 12),
        Expanded(child: Column(children: [children[1], children[3]])),
      ],
    );
  }

  Widget _buildInspirationItem(String imageUrl) {
    return GestureDetector(
      onTap: () => _showReimagineWithStyleSheet(
        Get.context!,
        'Custom Inspiration',
        imageUrl,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Image.network(imageUrl, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildAiReimagineCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2575FC).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Text(
                'AI Reimagine',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload a photo of your empty room and let our AI decorate it instantly.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showReimagineSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2575FC),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Try Virtual Staging',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showReimagineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReimagineUploadSheet(),
    );
  }

  void _showReimagineWithStyleSheet(
    BuildContext context,
    String styleName,
    String imageUrl,
  ) {
    _reimagineController.referenceImageUrl.value = imageUrl;
    _reimagineController.referenceStyleName.value = styleName;
    _reimagineController.selectedImage.value = null; // Clear previous upload

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReimagineUploadSheet(isStyleReference: true),
    );
  }
}

class ReimagineUploadSheet extends StatelessWidget {
  final bool isStyleReference;
  const ReimagineUploadSheet({super.key, this.isStyleReference = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ReimagineController>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isStyleReference ? 'Get This Look' : 'Start Transformation',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              isStyleReference
                  ? 'We will apply this design to your room'
                  : 'Select a style and upload your room photo',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isStyleReference && controller.referenceImageUrl.value != null) ...[
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: NetworkImage(controller.referenceImageUrl.value!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black26,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (!isStyleReference) ...[
                      const Text(
                        'SELECT DECOR STYLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStyleGrid(controller),
                      const SizedBox(height: 20),
                      
                      const Text(
                        'CUSTOM INSTRUCTIONS (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          maxLines: 2,
                          onChanged: (val) => controller.customPrompt.value = val,
                          decoration: const InputDecoration(
                            hintText: 'e.g. green velvet sofa, oak wooden coffee table, large window plants...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text(
                      'UPLOAD YOUR ROOM PHOTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: () => controller.pickImage(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: controller.selectedImage.value != null
                              ? Colors.transparent
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: controller.selectedImage.value != null
                                ? AppTheme.primaryBlue
                                : Colors.grey.shade200,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          image: controller.selectedImage.value != null
                              ? DecorationImage(
                                  image: FileImage(controller.selectedImage.value!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: controller.selectedImage.value != null
                            ? const SizedBox(height: 120)
                            : const Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Upload empty room',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'The room you want to redesign',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // Fixed CTA Button / Loading at the bottom
            if (controller.isGenerating.value)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.progressMessage.value,
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () => controller.generateDesign(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Reimagine My Room',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleGrid(ReimagineController controller) {
    final styles = [
      {'name': 'Modern', 'icon': Icons.chair_outlined},
      {'name': 'Scandinavian', 'icon': Icons.filter_hdr_outlined},
      {'name': 'Industrial', 'icon': Icons.precision_manufacturing_outlined},
      {'name': 'Bohemian', 'icon': Icons.wb_sunny_outlined},
      {'name': 'Minimalist', 'icon': Icons.check_circle_outline},
      {'name': 'Luxury', 'icon': Icons.workspace_premium_outlined},
    ];

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: styles.length,
        itemBuilder: (context, index) {
          final style = styles[index];
          bool isSelected = controller.selectedStyle.value == style['name'];
          return GestureDetector(
            onTap: () {
              controller.selectedStyle.value = style['name'] as String;
              // If style reference was active, clear it when selecting a preset
              controller.referenceStyleName.value = null;
              controller.referenceImageUrl.value = null;
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    style['icon'] as IconData,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    style['name'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
