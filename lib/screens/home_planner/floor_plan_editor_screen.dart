// import 'package:decor_ar_fyp/screens/home_planner/ar_preview_from_plan_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'dart:math' as math;
// import '../../controllers/home_planner_controller.dart';
// import '../../controllers/catalog_controller.dart';
// import '../../models/room_dimensions.dart';
// import '../../core/app_theme.dart';

// class FloorPlanEditorScreen extends StatefulWidget {
//   const FloorPlanEditorScreen({super.key});
//   @override State<FloorPlanEditorScreen> createState() => _FloorPlanEditorScreenState();
// }

// class _FloorPlanEditorScreenState extends State<FloorPlanEditorScreen> {
//   final _planner = Get.find<HomePlannerController>();
//   final _catalog = Get.find<CatalogController>();
//   String? _selectedElementId;
//   FloorPlanElementType _activeTool = FloorPlanElementType.furniture;

//   double get _roomW => _planner.roomDimensions.value?.widthMeters ?? 4.0;
//   double get _roomD => _planner.roomDimensions.value?.depthMeters ?? 3.5;

  
//   Offset? _dragStart;
//   FloorPlanElement? _draggingEl;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppTheme.backgroundLight,
//       appBar: AppBar(
//         title: const Text('Floor plan', style: TextStyle(fontWeight: FontWeight.bold)),
//         actions: [
//           IconButton(icon: const Icon(Icons.save_outlined),
//               onPressed: () async { await _planner.save(); Get.snackbar('Saved', 'Floor plan saved'); }),
//           IconButton(icon: const Icon(Icons.view_in_ar),
//               onPressed: () => Get.to(() => const ArPreviewFromPlanScreen()),
//               tooltip: 'Preview in AR'),
//         ],
//       ),
//       body: Column(children: [
//         _buildDimensionBanner(),
//         _buildToolbar(),
//         Expanded(child: Row(children: [
//           Expanded(child: _buildCanvas()),
//           _buildFurniturePalette(),
//         ])),
//       ]),
//     );
//   }

//   Widget _buildDimensionBanner() {
//     return Obx(() {
//       final rd = _planner.roomDimensions.value;
//       if (rd == null) return const SizedBox.shrink();
//       return Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         color: AppTheme.primaryBlue.withOpacity(0.08),
//         child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
//           _stat('Width', '${rd.widthMeters.toStringAsFixed(1)} m'),
//           _stat('Depth', '${rd.depthMeters.toStringAsFixed(1)} m'),
//           _stat('Area', '${rd.floorArea.toStringAsFixed(1)} m²'),
//           _stat('Items', '${rd.elements.where((e) => e.type == FloorPlanElementType.furniture).length}'),
//         ]),
//       );
//     });
//   }

//   Widget _stat(String label, String value) => Column(children: [
//     Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//     Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
//   ]);

//   Widget _buildToolbar() {
//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       child: Row(children: [
//         Flexible(
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(children: [
//               _toolBtn(Icons.chair, 'Furniture', FloorPlanElementType.furniture),
//               const SizedBox(width: 8),
//               _toolBtn(Icons.door_front_door, 'Door', FloorPlanElementType.door),
//               const SizedBox(width: 8),
//               _toolBtn(Icons.window, 'Window', FloorPlanElementType.window),
//             ]),
//           ),
//         ),
//         const SizedBox(width: 4),
//         if (_selectedElementId != null)
//           TextButton.icon(
//             onPressed: () {
//               _planner.removeElement(_selectedElementId!);
//               setState(() => _selectedElementId = null);
//             },
//             icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
//             label: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
//           ),
//         TextButton.icon(
//           onPressed: () {
//             _planner.roomDimensions.value?.elements.clear();
//             _planner.roomDimensions.refresh();
//             setState(() => _selectedElementId = null);
//           },
//           icon: const Icon(Icons.clear_all, size: 18),
//           label: const Text('Clear', style: TextStyle(fontSize: 12)),
//         ),
//       ]),
//     );
//   }

//   Widget _toolBtn(IconData icon, String label, FloorPlanElementType type) {
//     final active = _activeTool == type;
//     return GestureDetector(
//       onTap: () => setState(() => _activeTool = type),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: active ? AppTheme.primaryBlue : Colors.transparent,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: active ? AppTheme.primaryBlue : Colors.grey.shade300),
//         ),
//         child: Row(children: [
//           Icon(icon, size: 16, color: active ? Colors.white : AppTheme.textGrey),
//           const SizedBox(width: 4),
//           Text(label, style: TextStyle(fontSize: 12,
//               color: active ? Colors.white : AppTheme.textGrey)),
//         ]),
//       ),
//     );
//   }

//   Widget _buildCanvas() {
//     return Obx(() {
//       final rd = _planner.roomDimensions.value;
//       if (rd == null) return const Center(child: CircularProgressIndicator());
//       return GestureDetector(
//         onTapDown: (d) => _handleCanvasTap(d.localPosition),
//         onPanStart: (d) => _onPanStart(d.localPosition),
//         onPanUpdate: (d) => _onPanUpdate(d.localPosition),
//         onPanEnd: (_) => _onPanEnd(),
//         child: DragTarget<Map<String, dynamic>>(
//           onAcceptWithDetails: (details) {
//             final renderBox = context.findRenderObject() as RenderBox;
//             final localPos = renderBox.globalToLocal(details.offset);
//             _addFromDrop(details.data, localPos);
//           },
//           builder: (context, candidateData, rejectedData) => LayoutBuilder(
//             builder: (ctx, constraints) => CustomPaint(
//               painter: _FloorPlanPainter(
//                 roomDimensions: rd,
//                 selectedId: _selectedElementId,
//                 canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
//               ),
//               child: Container(width: constraints.maxWidth, height: constraints.maxHeight),
//             ),
//           ),
//         ),
//       );
//     });
//   }

//   Widget _buildFurniturePalette() {
//     final items = [
//       {'name': 'Sofa', 'w': 2.1, 'd': 0.9, 'icon': Icons.chair},
//       {'name': 'Coffee table', 'w': 1.1, 'd': 0.6, 'icon': Icons.table_bar},
//       {'name': 'TV unit', 'w': 1.8, 'd': 0.5, 'icon': Icons.tv},
//       {'name': 'Dining table', 'w': 1.6, 'd': 0.9, 'icon': Icons.dining},
//       {'name': 'Chair', 'w': 0.6, 'd': 0.6, 'icon': Icons.chair_alt},
//       {'name': 'Bed (single)', 'w': 1.0, 'd': 2.0, 'icon': Icons.bed},
//       {'name': 'Bed (double)', 'w': 1.6, 'd': 2.0, 'icon': Icons.bed},
//       {'name': 'Wardrobe', 'w': 1.2, 'd': 0.6, 'icon': Icons.door_sliding},
//       {'name': 'Desk', 'w': 1.2, 'd': 0.6, 'icon': Icons.desk},
//       {'name': 'Bathtub', 'w': 1.6, 'd': 0.8, 'icon': Icons.bathtub},
//       {'name': 'Toilet', 'w': 0.4, 'd': 0.7, 'icon': Icons.wc},
//     ];

//     return Container(
//       width: 130,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(left: BorderSide(color: Colors.grey.shade200)),
//       ),
//       child: Column(children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           child: Text('Furniture', style: TextStyle(
//               fontSize: 11, fontWeight: FontWeight.bold,
//               color: Colors.grey.shade500, letterSpacing: 1)),
//         ),
//         Expanded(child: ListView.builder(
//           itemCount: items.length,
//           itemBuilder: (context, i) {
//             final item = items[i];
//             return Draggable<Map<String, dynamic>>(
//               data: item,
//               feedback: Material(
//                 color: AppTheme.primaryBlue.withOpacity(0.9),
//                 borderRadius: BorderRadius.circular(8),
//                 child: Padding(padding: const EdgeInsets.all(8),
//                   child: Text(item['name'] as String,
//                       style: const TextStyle(color: Colors.white, fontSize: 11))),
//               ),
//               childWhenDragging: Opacity(opacity: 0.4,
//                   child: _paletteItem(item)),
//               child: GestureDetector(
//                 onTap: () => _addFurnitureAtCenter(item),
//                 child: _paletteItem(item),
//               ),
//             );
//           },
//         )),
//       ]),
//     );
//   }

//   Widget _paletteItem(Map<String, dynamic> item) => Container(
//     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//     decoration: BoxDecoration(
//       color: Colors.grey.shade50,
//       borderRadius: BorderRadius.circular(8),
//       border: Border.all(color: Colors.grey.shade200),
//     ),
//     child: Row(children: [
//       Icon(item['icon'] as IconData, size: 16, color: AppTheme.primaryBlue),
//       const SizedBox(width: 6),
//       Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(item['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
//         Text('${item['w']}×${item['d']} m', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
//       ])),
//     ]),
//   );

  

//   Offset _worldToCanvas(double xM, double zM, Size canvasSize) {
//     const margin = 40.0;
//     final scale = math.min(
//       (canvasSize.width - 2 * margin) / _roomW,
//       (canvasSize.height - 2 * margin) / _roomD,
//     );
//     final ox = (canvasSize.width - _roomW * scale) / 2;
//     final oy = (canvasSize.height - _roomD * scale) / 2;
//     return Offset(ox + xM * scale, oy + zM * scale);
//   }

//   Offset _canvasToWorld(Offset canvas, Size canvasSize) {
//     const margin = 40.0;
//     final scale = math.min(
//       (canvasSize.width - 2 * margin) / _roomW,
//       (canvasSize.height - 2 * margin) / _roomD,
//     );
//     final ox = (canvasSize.width - _roomW * scale) / 2;
//     final oy = (canvasSize.height - _roomD * scale) / 2;
//     return Offset((canvas.dx - ox) / scale, (canvas.dy - oy) / scale);
//   }

//   void _handleCanvasTap(Offset localPos) {
//     final rd = _planner.roomDimensions.value; if (rd == null) return;
    
//     if (_activeTool == FloorPlanElementType.door ||
//         _activeTool == FloorPlanElementType.window) {
//       final renderBox = context.findRenderObject() as RenderBox;
//       final canvasSize = renderBox.size;
//       final worldPos = _canvasToWorld(localPos, canvasSize);
//       _planner.addElement(FloorPlanElement(
//         id: 'el_${DateTime.now().millisecondsSinceEpoch}',
//         type: _activeTool,
//         xMeters: worldPos.dx.clamp(0, _roomW),
//         zMeters: worldPos.dy.clamp(0, _roomD),
//         widthMeters: _activeTool == FloorPlanElementType.door ? 0.9 : 1.2,
//         depthMeters: 0.1,
//       ));
//       return;
//     }
    
//     final renderBox2 = context.findRenderObject() as RenderBox;
//     final worldPos = _canvasToWorld(localPos, renderBox2.size);
//     const margin = 40.0;
//     final scale = math.min(
//       (renderBox2.size.width - 2 * margin) / _roomW,
//       (renderBox2.size.height - 2 * margin) / _roomD,
//     );
//     String? hitId;
//     for (final el in rd.elements.reversed) {
//       final hw = el.widthMeters / 2, hd = el.depthMeters / 2;
//       if (worldPos.dx >= el.xMeters - hw && worldPos.dx <= el.xMeters + hw &&
//           worldPos.dy >= el.zMeters - hd && worldPos.dy <= el.zMeters + hd) {
//         hitId = el.id; break;
//       }
//     }
//     setState(() => _selectedElementId = hitId);
//   }

//   void _onPanStart(Offset localPos) {
//     final rd = _planner.roomDimensions.value; if (rd == null) return;
//     final renderBox = context.findRenderObject() as RenderBox;
//     final worldPos = _canvasToWorld(localPos, renderBox.size);
//     for (final el in rd.elements.reversed) {
//       final hw = el.widthMeters / 2, hd = el.depthMeters / 2;
//       if (worldPos.dx >= el.xMeters - hw && worldPos.dx <= el.xMeters + hw &&
//           worldPos.dy >= el.zMeters - hd && worldPos.dy <= el.zMeters + hd) {
//         _draggingEl = el;
//         _dragStart = Offset(worldPos.dx - el.xMeters, worldPos.dy - el.zMeters);
//         setState(() => _selectedElementId = el.id);
//         return;
//       }
//     }
//   }

//   void _onPanUpdate(Offset localPos) {
//     if (_draggingEl == null || _dragStart == null) return;
//     final renderBox = context.findRenderObject() as RenderBox;
//     final worldPos = _canvasToWorld(localPos, renderBox.size);
//     final newX = (worldPos.dx - _dragStart!.dx).clamp(0.0, _roomW);
//     final newZ = (worldPos.dy - _dragStart!.dy).clamp(0.0, _roomD);
//     _draggingEl!.xMeters = newX;
//     _draggingEl!.zMeters = newZ;
//     _planner.roomDimensions.refresh();
//   }

//   void _onPanEnd() { _draggingEl = null; _dragStart = null; }

//   void _addFromDrop(Map<String, dynamic> data, Offset localPos) {
//     final renderBox = context.findRenderObject() as RenderBox;
//     final worldPos = _canvasToWorld(localPos, renderBox.size);
//     _planner.addElement(FloorPlanElement(
//       id: 'el_${DateTime.now().millisecondsSinceEpoch}',
//       type: FloorPlanElementType.furniture,
//       xMeters: worldPos.dx.clamp(0, _roomW),
//       zMeters: worldPos.dy.clamp(0, _roomD),
//       widthMeters: (data['w'] as num).toDouble(),
//       depthMeters: (data['d'] as num).toDouble(),
//     ));
//   }

//   void _addFurnitureAtCenter(Map<String, dynamic> data) {
//     _planner.addElement(FloorPlanElement(
//       id: 'el_${DateTime.now().millisecondsSinceEpoch}',
//       type: FloorPlanElementType.furniture,
//       xMeters: _roomW / 2,
//       zMeters: _roomD / 2,
//       widthMeters: (data['w'] as num).toDouble(),
//       depthMeters: (data['d'] as num).toDouble(),
//     ));
//   }
// }



// class _FloorPlanPainter extends CustomPainter {
//   final RoomDimensions roomDimensions;
//   final String? selectedId;
//   final Size canvasSize;

//   _FloorPlanPainter({
//     required this.roomDimensions,
//     this.selectedId,
//     required this.canvasSize,
//   });

//   double get rW => roomDimensions.widthMeters;
//   double get rD => roomDimensions.depthMeters;

//   double get scale {
//     const margin = 40.0;
//     return math.min(
//       (canvasSize.width - 2 * margin) / rW,
//       (canvasSize.height - 2 * margin) / rD,
//     );
//   }

//   Offset get origin => Offset(
//     (canvasSize.width - rW * scale) / 2,
//     (canvasSize.height - rD * scale) / 2,
//   );

//   Offset toCanvas(double xM, double zM) =>
//       Offset(origin.dx + xM * scale, origin.dy + zM * scale);

//   @override
//   void paint(Canvas canvas, Size size) {
    
//     final gridPaint = Paint()
//       ..color = Colors.grey.withOpacity(0.12)
//       ..strokeWidth = 0.5;
//     for (double x = 0; x <= rW + 0.01; x += 1.0) {
//       final p = toCanvas(x, 0); final p2 = toCanvas(x, rD);
//       canvas.drawLine(p, p2, gridPaint);
//     }
//     for (double z = 0; z <= rD + 0.01; z += 1.0) {
//       final p = toCanvas(0, z); final p2 = toCanvas(rW, z);
//       canvas.drawLine(p, p2, gridPaint);
//     }

    
//     final floorRect = Rect.fromLTWH(origin.dx, origin.dy, rW * scale, rD * scale);
//     canvas.drawRect(floorRect, Paint()..color = Colors.white);

    
//     final wallPaint = Paint()
//       ..color = const Color(0xFF1A1A2E)
//       ..strokeWidth = 4
//       ..style = PaintingStyle.stroke;
//     canvas.drawRect(floorRect, wallPaint);

    
//     final tp = (String text, Offset pos, {bool rotated = false}) {
//       final span = TextSpan(
//         text: text,
//         style: const TextStyle(color: Color(0xFF185FA5), fontSize: 11, fontWeight: FontWeight.w500),
//       );
//       final painter = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
//       if (rotated) {
//         canvas.save();
//         canvas.translate(pos.dx, pos.dy);
//         canvas.rotate(-math.pi / 2);
//         painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
//         canvas.restore();
//       } else {
//         painter.paint(canvas, Offset(pos.dx - painter.width / 2, pos.dy - painter.height / 2));
//       }
//     };
//     tp('${rW.toStringAsFixed(1)} m', Offset(origin.dx + rW * scale / 2, origin.dy - 14));
//     tp('${rD.toStringAsFixed(1)} m', Offset(origin.dx - 20, origin.dy + rD * scale / 2), rotated: true);

    
//     for (final el in roomDimensions.elements) {
//       final cx = toCanvas(el.xMeters, el.zMeters);
//       final rect = Rect.fromCenter(center: cx,
//           width: el.widthMeters * scale, height: el.depthMeters * scale);
//       final isSelected = el.id == selectedId;

//       Color fillColor;
//       switch (el.type) {
//         case FloorPlanElementType.door:
//           fillColor = const Color(0xFFFAC775);
//           _drawDoor(canvas, cx, el.widthMeters * scale, isSelected); continue;
//         case FloorPlanElementType.window:
//           fillColor = const Color(0xFFB5D4F4);
//           _drawWindow(canvas, cx, el.widthMeters * scale, isSelected); continue;
//         case FloorPlanElementType.furniture:
//           fillColor = const Color(0xFFE6F1FB);
//       }

//       canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
//           Paint()..color = fillColor);
//       canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
//           Paint()
//             ..color = isSelected ? AppTheme.primaryBlue : Colors.blueGrey.withOpacity(0.5)
//             ..strokeWidth = isSelected ? 2 : 0.5
//             ..style = PaintingStyle.stroke);

      
//       if (el.widthMeters * scale > 24) {
//         final span = TextSpan(
//           text: '${el.widthMeters.toStringAsFixed(1)}×${el.depthMeters.toStringAsFixed(1)}',
//           style: TextStyle(color: AppTheme.primaryBlue, fontSize: math.min(10, el.widthMeters * scale / 5)),
//         );
//         final painter = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
//         painter.paint(canvas, cx - Offset(painter.width / 2, painter.height / 2));
//       }
//     }
//   }

//   void _drawDoor(Canvas c, Offset center, double w, bool sel) {
//     final p = Paint()..color = const Color(0xFF854F0B)..strokeWidth = sel ? 2 : 1.5..style = PaintingStyle.stroke;
//     c.drawLine(center, center + Offset(w / 2, 0), p);
//     c.drawArc(Rect.fromCenter(center: center, width: w, height: w),
//         0, math.pi / 2, false, p..style = PaintingStyle.stroke..color = const Color(0xFFEF9F27).withOpacity(0.6));
//   }

//   void _drawWindow(Canvas c, Offset center, double w, bool sel) {
//     final p = Paint()..color = const Color(0xFF185FA5)..strokeWidth = sel ? 2 : 1;
//     for (double off in [-4.0, 0.0, 4.0]) {
//       c.drawLine(center + Offset(-w / 2, off), center + Offset(w / 2, off), p);
//     }
//   }

//   @override bool shouldRepaint(_FloorPlanPainter old) => true;
// }