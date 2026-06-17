import 'dart:convert';
import 'dart:typed_data';
import 'package:decor_ar_fyp/controllers/catalog_controller.dart';
import 'package:decor_ar_fyp/controllers/project_controller_firestore.dart';
import 'package:decor_ar_fyp/screens/ar_view_screen.dart';
import 'package:decor_ar_fyp/services/firestore_project_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:decor_ar_fyp/controllers/room_planner_controller.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ThreeFloorPlanScreen extends StatefulWidget {
  final Project? project;
  const ThreeFloorPlanScreen({super.key, this.project});

  @override
  State<ThreeFloorPlanScreen> createState() => _ThreeFloorPlanScreenState();
}

class _ThreeFloorPlanScreenState extends State<ThreeFloorPlanScreen> {
  InAppWebViewController? _webViewController;
  bool _webViewReady = false;
  bool _is3DView = false;
  bool _showSidebar = true;
  String? _selectedName;
  Project? _currentProject;

  late RoomPlannerController _plannerCtrl;
  late CatalogController _catalogCtrl;

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    _plannerCtrl = Get.isRegistered<RoomPlannerController>()
        ? Get.find<RoomPlannerController>()
        : Get.put(RoomPlannerController());
    _catalogCtrl = Get.isRegistered<CatalogController>()
        ? Get.find<CatalogController>()
        : Get.put(CatalogController());

    
    if (_currentProject?.layoutData != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(_currentProject!.layoutData!);
        if (data['roomWidth'] != null) {
          _plannerCtrl.roomWidth.value = (data['roomWidth'] as num).toDouble();
          _plannerCtrl.widthController.text = _plannerCtrl.roomWidth.value.toString();
        }
        if (data['roomLength'] != null) {
          _plannerCtrl.roomLength.value = (data['roomLength'] as num).toDouble();
          _plannerCtrl.lengthController.text = _plannerCtrl.roomLength.value.toString();
        }
        if (data['roomHeight'] != null) {
          _plannerCtrl.roomHeight.value = (data['roomHeight'] as num).toDouble();
          _plannerCtrl.heightController.text = _plannerCtrl.roomHeight.value.toString();
        }
      } catch (e) {
        print('[THREE] Error parsing project layout for dimensions: $e');
      }
    }
  }
  void _sendRoomDimensions() {
    if (!_webViewReady || _webViewController == null) return;
    final w = _plannerCtrl.roomWidth.value;
    final l = _plannerCtrl.roomLength.value;
    final h = _plannerCtrl.roomHeight.value;
    _webViewController!.evaluateJavascript(
      source: "window.updateRoom($w, $l, $h, 'Modern');",
    );
  }

  void _addFurnitureToWeb(Map<String, dynamic> item) {
    if (!_webViewReady || _webViewController == null) return;
    final dims = item['dims'] as List? ?? [0.8, 0.8, 0.8];
    final w = (dims[0] as num).toDouble();
    final d = (dims.length > 2 ? dims[2] as num : dims[0] as num).toDouble();
    final name = item['name'] ?? 'Item';
    final modelUrl = item['model'] ?? '';
    final type = _mapToType(name);
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';

    _webViewController!.evaluateJavascript(
      source:
          "window.addFurniture('$id', '$type', '$name', $w, $d, '$modelUrl');",
    );
  }

  String _mapToType(String name) {
    final n = name.toLowerCase();
    if (n.contains('sofa')) return 'sofa';
    if (n.contains('bed')) return 'bed';
    if (n.contains('table')) return 'table';
    if (n.contains('wardrobe')) return 'wardrobe';
    if (n.contains('plant')) return 'plant';
    if (n.contains('tv')) return 'tv_unit';
    return 'generic';
  }

  void _toggleView() {
    if (!_webViewReady || _webViewController == null) return;
    setState(() => _is3DView = !_is3DView);
    _webViewController!.evaluateJavascript(
      source:
          "if(typeof window.setView==='function'){window.setView('${_is3DView ? "3d" : "2d"}')};",
    );
  }

  void _rotateSelected() {
    if (!_webViewReady || _webViewController == null) return;
    _webViewController!.evaluateJavascript(
      source:
          "if(typeof window.rotateSelected==='function'){window.rotateSelected()};",
    );
  }

  void _deleteSelected() {
    if (!_webViewReady || _webViewController == null) return;
    _webViewController!.evaluateJavascript(
      source:
          "if(typeof window.deleteSelected==='function'){window.deleteSelected()};",
    );
    setState(() => _selectedName = null);
  }

  void _exportLayout() {
    if (!_webViewReady || _webViewController == null) return;
    _webViewController!.evaluateJavascript(
      source:
          "if(typeof window.exportLayout==='function'){window.exportLayout()};",
    );
  }

  
  Future<String?> _showNameDialog() async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Save Project As', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter project name...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent),
            ),
          ),
          onChanged: (val) => name = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  
  Future<void> _saveProject() async {
    if (!_webViewReady || _webViewController == null) return;
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: "window.getLayoutData();",
      );
      if (result != null && result.toString().isNotEmpty) {
        
        String jsonStr = result.toString();
        
        if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
          jsonStr = jsonDecode(jsonStr) as String;
        }

        
        final Map<String, dynamic> layoutMap = jsonDecode(jsonStr);
        final placements = layoutMap['placements'] as List? ?? [];
        final items = placements.map((p) {
          final pMap = Map<String, dynamic>.from(p as Map);
          return FurniturePlacement(
            modelUri: _findModelUri(pMap['type'] as String),
            position: vector.Vector3(
              (pMap['x'] as num).toDouble(),
              (pMap['y'] as num).toDouble(),
              (pMap['z'] as num).toDouble(),
            ),
            rotation: vector.Vector4(
              0,
              1,
              0,
              (pMap['rotationY'] as num).toDouble(),
            ),
            scale: vector.Vector3(1, 1, 1),
          );
        }).toList();

        
        String? name = _currentProject?.name;
        if (name == null || name.isEmpty) {
          name = await _showNameDialog();
          if (name == null || name.trim().isEmpty) return; 
        }

        final projectController = Get.find<ProjectController>();
        final newProject = Project(
          id: _currentProject?.id ?? '', 
          name: name,
          roomType: 'Living Room',
          style: 'Modern',
          lastModified: DateTime.now(),
          items: items,
          layoutData: jsonStr,
          thumbnailPath: _currentProject?.thumbnailPath,
        );

        await projectController.saveProject(newProject);

        try {
          final screenshotData = await _webViewController!.evaluateJavascript(
            source: "window.takeScreenshot();",
          );
          if (screenshotData != null &&
              screenshotData.toString().startsWith('data:image/png;base64,')) {
            final String base64Str = screenshotData
                .toString()
                .substring('data:image/png;base64,'.length);
            final Uint8List bytes = base64Decode(base64Str);
            final url = await FirestoreProjectService()
                .uploadThumbnail(newProject.id, bytes);
            newProject.thumbnailPath = url;
          }
        } catch (e) {
          print('[THREE] Thumbnail upload failed: $e');
        }

        setState(() {
          _currentProject = newProject;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "$name" saved successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[THREE] Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  
  Future<void> _restoreSavedLayout() async {
    if (!_webViewReady || _webViewController == null) return;
    final layoutJson = _currentProject?.layoutData;
    if (layoutJson == null || layoutJson.isEmpty) return;
    try {
      
      final escaped = layoutJson
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      await _webViewController!.evaluateJavascript(
        source: "window.loadLayout('$escaped');",
      );
      print('[THREE] Layout restored from project: ${_currentProject!.name}');
    } catch (e) {
      print('[THREE] Restore error: $e');
    }
  }

  
  void _handleLayoutExport(Map<String, dynamic>? data) {
    if (data == null) return;
    try {
      final placements = data['placements'] as List;

      final items = placements.map((p) {
        final pMap = Map<String, dynamic>.from(p as Map);
        return FurniturePlacement(
          modelUri: _findModelUri(pMap['type'] as String),
          position: vector.Vector3(
            (pMap['x'] as num).toDouble(),
            0,
            (pMap['z'] as num).toDouble(),
          ),
          rotation: vector.Vector4(
            0,
            1,
            0,
            (pMap['rotationY'] as num).toDouble() * 3.14159 / 180,
          ),
          scale: vector.Vector3(1, 1, 1),
        );
      }).toList();

      final project = Project(
        id: 'three_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Floor Plan Design',
        roomType: 'Living Room',
        style: 'Modern',
        lastModified: DateTime.now(),
        items: items,
      );

      Get.to(() => ArViewScreen(project: project));
    } catch (e) {
      print('[THREE] Export error: $e');
    }
  }

  String _findModelUri(String type) {
    final item = _catalogCtrl.furnitureItems.firstWhereOrNull(
      (i) => (i['name'] as String).toLowerCase().contains(type.toLowerCase()),
    );
    return item?['model'] ?? '';
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          
          Expanded(
            child: Row(
              children: [
                
                Expanded(
                  child: Stack(
                    children: [
                      InAppWebView(
                        initialFile: "assets/web/index.html",
                        initialSettings: InAppWebViewSettings(
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                          useShouldOverrideUrlLoading: true,
                          mediaPlaybackRequiresUserGesture: false,
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;

                          
                          controller.addJavaScriptHandler(
                            handlerName:
                                'onUnityReady', 
                            callback: (args) {
                              setState(() => _webViewReady = true);
                              _sendRoomDimensions();
                              
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                _restoreSavedLayout,
                              );
                            },
                          );

                          controller.addJavaScriptHandler(
                            handlerName: 'onSelected',
                            callback: (args) {
                              setState(() {
                                final Map<dynamic, dynamic>? item =
                                    args.isNotEmpty ? args[0] : null;
                                _selectedName = item?['name']?.toString();
                              });
                            },
                          );

                          controller.addJavaScriptHandler(
                            handlerName: 'onLayoutExported',
                            callback: (args) {
                              final Map<dynamic, dynamic>? data =
                                  args.isNotEmpty ? args[0] : null;
                              if (data != null) {
                                _handleLayoutExport(
                                  Map<String, dynamic>.from(data),
                                );
                              }
                            },
                          );

                          controller.addJavaScriptHandler(
                            handlerName: 'onRoomBuilt',
                            callback: (args) {
                              print('[THREE] Room built successfully');
                            },
                          );

                          controller.addJavaScriptHandler(
                            handlerName: 'onLayoutLoaded',
                            callback: (args) {
                              final data = args.isNotEmpty ? args[0] : null;
                              print('[THREE] Layout loaded: $data');
                            },
                          );
                        },
                        onLoadStop: (controller, url) async {
                          
                          
                          if (!_webViewReady) {
                            setState(() => _webViewReady = true);
                            
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            _sendRoomDimensions();
                            
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              _restoreSavedLayout,
                            );
                          }
                        },
                        onConsoleMessage: (controller, consoleMessage) {
                          print('[THREE CONSOLE] ${consoleMessage.message}');
                        },
                      ),

                      
                      if (!_webViewReady)
                        Container(
                          color: const Color(0xFF0F172A),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.cyanAccent,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Building 3D Floor Plan...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      
                      if (_selectedName != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '✓ $_selectedName selected',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                
                if (_showSidebar) _buildCatalogSidebar(),
              ],
            ),
          ),

          
          _buildToolbar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      title: Obx(
        () => Text(
          '${_plannerCtrl.roomWidth.value.toStringAsFixed(1)}m × ${_plannerCtrl.roomLength.value.toStringAsFixed(1)}m',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      actions: [
        
        IconButton(
          icon: const Icon(Icons.save_outlined, color: Colors.white70),
          onPressed: _webViewReady ? _saveProject : null,
          tooltip: 'Save project',
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [_viewBtn('2D', !_is3DView), _viewBtn('3D', _is3DView)],
          ),
        ),
        
        IconButton(
          icon: const Icon(Icons.straighten, color: Colors.white70),
          onPressed: _showDimEditor,
        ),
        
        IconButton(
          icon: Icon(
            _showSidebar ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _showSidebar = !_showSidebar),
        ),
      ],
    );
  }

  Widget _viewBtn(String label, bool active) {
    return GestureDetector(
      onTap: () {
        if ((label == '3D') != _is3DView) _toggleView();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.cyanAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogSidebar() {
    return Container(
      width: 95,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),

        border: Border(left: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Catalog',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: Obx(
              () => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _catalogCtrl.furnitureItems.length,
                itemBuilder: (_, i) {
                  final item = _catalogCtrl.furnitureItems[i];
                  return _catalogTile(item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogTile(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _addFurnitureToWeb(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            const Icon(Icons.chair, color: Colors.cyanAccent, size: 28),
            const SizedBox(height: 4),
            Text(
              item['name'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),

        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolBtn(
            Icons.rotate_right,
            'Rotate',
            _selectedName != null ? _rotateSelected : null,
          ),
          _toolBtn(
            Icons.delete_outline,
            'Delete',
            _selectedName != null ? _deleteSelected : null,
            color: Colors.redAccent,
          ),
          _toolBtn(
            Icons.view_in_ar,
            'To AR',
            _webViewReady ? _exportLayout : null,
            color: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showDimEditor() {
    final c = _plannerCtrl;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Room Dimensions',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dimField('Width (m)', c.widthController),
            const SizedBox(height: 12),
            _dimField('Length (m)', c.lengthController),
            const SizedBox(height: 12),
            _dimField('Height (m)', c.heightController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              c.applyManualDimensions();
              _sendRoomDimensions();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _dimField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
