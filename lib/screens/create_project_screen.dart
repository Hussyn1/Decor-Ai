import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/project_service.dart';
import 'ar_view_screen.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  String selectedRoom = 'Living Room';
  String selectedStyle = 'Modern';
  final TextEditingController _nameController = TextEditingController();

  final List<Map<String, dynamic>> roomTypes = [
    {'name': 'Living Room', 'icon': Icons.weekend_outlined},
    {'name': 'Bedroom', 'icon': Icons.bed_outlined},
    {'name': 'Kitchen', 'icon': Icons.kitchen_outlined},
    {'name': 'Office', 'icon': Icons.work_outline},
    {'name': 'Dining', 'icon': Icons.restaurant_outlined},
  ];

  final List<String> styles = [
    'Modern',
    'Minimalist',
    'Scandinavian',
    'Industrial',
    'Bohemian',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'New Project',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              label: 'Project Name',
              hint: 'e.g., My Dream Living Room',
              prefixIcon: Icons.edit_note_rounded,
              controller: _nameController,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle('Room Type'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: roomTypes.map((room) => _buildRoomChip(room)).toList(),
            ),

            const SizedBox(height: 32),
            _buildSectionTitle('Interior Style'),
            const SizedBox(height: 16),
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: styles.length,
                itemBuilder: (context, index) => _buildStyleChip(styles[index]),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionTitle('AI Assistant (Optional)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable AI Style Advice',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Get personalized color and furniture tips',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (val) {},
                    activeColor: AppTheme.primaryBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            PrimaryButton(
              text: 'Initialize Project',
              onPressed: () {
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a project name"),
                    ),
                  );
                  return;
                }

                // Create new project object
                final newProject = Project(
                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                  name: _nameController.text,
                  roomType: selectedRoom,
                  style: selectedStyle,
                  lastModified: DateTime.now(),
                  items: [],
                );

                // Navigate to AR View with this project
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArViewScreen(project: newProject),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildRoomChip(Map<String, dynamic> room) {
    bool isSelected = selectedRoom == room['name'];
    return GestureDetector(
      onTap: () => setState(() => selectedRoom = room['name']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              room['icon'],
              size: 20,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              room['name'],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleChip(String style) {
    bool isSelected = selectedStyle == style;
    return GestureDetector(
      onTap: () => setState(() => selectedStyle = style),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            style,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade500,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
