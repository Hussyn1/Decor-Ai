import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

// ─── Models ──────────────────────────────────────────────────────────────────
// Drop-in replacements for the classes in your existing project_service.dart

class FurniturePlacement {
  final String modelUri;
  final vector.Vector3 position;
  final vector.Vector4 rotation;
  final vector.Vector3 scale;
  final String? cloudAnchorId; // kept for compat, never used

  FurniturePlacement({
    required this.modelUri,
    required this.position,
    required this.rotation,
    required this.scale,
    this.cloudAnchorId,
  });

  Map<String, dynamic> toJson() {
    double s(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;
    return {
      'modelUri': modelUri,
      'position': [s(position.x), s(position.y), s(position.z)],
      'rotation': [s(rotation.x), s(rotation.y), s(rotation.z), s(rotation.w)],
      'scale':    [s(scale.x),    s(scale.y),    s(scale.z)],
    };
  }

  factory FurniturePlacement.fromJson(Map<String, dynamic> json) {
    final pos = (json['position'] as List).map((e) => (e as num).toDouble()).toList();
    final rot = (json['rotation'] as List).map((e) => (e as num).toDouble()).toList();
    final sc  = (json['scale']    as List).map((e) => (e as num).toDouble()).toList();
    return FurniturePlacement(
      modelUri: json['modelUri'] as String,
      position: vector.Vector3(pos[0], pos[1], pos[2]),
      rotation: vector.Vector4(rot[0], rot[1], rot[2], rot[3]),
      scale:    vector.Vector3(sc[0],  sc[1],  sc[2]),
    );
  }
}

class Project {
  String id;
  String name;
  String roomType;
  String style;
  DateTime lastModified;
  List<FurniturePlacement> items;
  String? thumbnailPath;
  String? layoutData;

  Project({
    required this.id,
    required this.name,
    required this.roomType,
    required this.style,
    required this.lastModified,
    this.items = const [],
    this.thumbnailPath,
    this.layoutData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roomType': roomType,
    'style': style,
    'lastModified': lastModified.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'thumbnailUrl': thumbnailPath,
    'layoutData': layoutData,
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? [];
    return Project(
      id:           (json['id'] ?? json['_id'] ?? '') as String,
      name:         (json['name'] ?? 'Untitled') as String,
      roomType:     (json['roomType'] ?? 'Living Room') as String,
      style:        (json['style'] ?? 'Modern') as String,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
      items: itemsJson
          .map((i) => FurniturePlacement.fromJson(i as Map<String, dynamic>))
          .toList(),
      thumbnailPath: (json['thumbnailPath'] ?? json['thumbnailUrl']) as String?,
      layoutData: json['layoutData'] as String?,
    );
  }
}

// ─── Firestore Service ────────────────────────────────────────────────────────

class FirestoreProjectService {
  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Returns a stable user identifier.
  /// Tries Firebase Auth first, then falls back to the MongoDB _id stored
  /// by your existing AuthController so no auth migration is required.
  Future<String?> _getUserId() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) return firebaseUser.uid;

    final prefs = await SharedPreferences.getInstance();
    final rawUserData = prefs.getString('user_data');
    if (rawUserData != null) {
      try {
        final map = jsonDecode(rawUserData) as Map<String, dynamic>;
        final uid = (map['_id'] ?? map['id'])?.toString();
        if (uid != null && uid.isNotEmpty) return uid;
      } catch (_) {}
    }
    // Last resort: use the token itself as a stable key
    return prefs.getString('auth_token');
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('projects');

  // ── SAVE ────────────────────────────────────────────────────────────────────

  /// Saves (or upserts) a project.  
  /// Updates [project.id] in-place when a new project gets a real Firestore ID.
  Future<void> saveProject(Project project) async {
    final uid = await _getUserId();
    if (uid == null) throw Exception('Not authenticated');

    final isNew = project.id.isEmpty ||
        project.id.startsWith('temp_') ||
        project.id.startsWith('plan_') ||
        project.id.startsWith('fcm_');

    final docRef = isNew ? _col(uid).doc() : _col(uid).doc(project.id);

    await docRef.set({
      'name':         project.name,
      'roomType':     project.roomType,
      'style':        project.style,
      'lastModified': project.lastModified.toIso8601String(),
      'thumbnailUrl': project.thumbnailPath,
      'layoutData':   project.layoutData,
      // Serialize each placement as a plain map — no Cloud Anchor IDs needed
      'items': project.items.map((i) => i.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (isNew) {
      project.id = docRef.id;
      print('[Firestore] Created project ${project.id}');
    } else {
      print('[Firestore] Updated project ${project.id} with ${project.items.length} items');
    }
  }

  // ── LOAD ALL ─────────────────────────────────────────────────────────────────

  Future<List<Project>> loadProjects() async {
    final uid = await _getUserId();
    if (uid == null) return [];

    try {
      final snap = await _col(uid)
          .orderBy('updatedAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id; // inject real Firestore doc ID
        return Project.fromJson(data);
      }).toList();
    } catch (e) {
      print('[Firestore] loadProjects error: $e');
      return [];
    }
  }

  // ── LOAD SINGLE ──────────────────────────────────────────────────────────────

  Future<Project?> loadProject(String projectId) async {
    final uid = await _getUserId();
    if (uid == null) return null;

    try {
      final doc = await _col(uid).doc(projectId).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return Project.fromJson(data);
    } catch (e) {
      print('[Firestore] loadProject error: $e');
      return null;
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────

  Future<void> deleteProject(String id) async {
    final uid = await _getUserId();
    if (uid == null) throw Exception('Not authenticated');
    await _col(uid).doc(id).delete();
    print('[Firestore] Deleted project $id');
  }

  // ── THUMBNAIL ────────────────────────────────────────────────────────────────

  Future<String> uploadThumbnail(String projectId, Uint8List bytes) async {
    final uid = await _getUserId();
    if (uid == null) throw Exception('Not authenticated');

    final ref = _storage.ref().child('thumbnails/$uid/$projectId.png');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    final url = await ref.getDownloadURL();

    // Persist URL back to the project document
    await _col(uid).doc(projectId).update({'thumbnailUrl': url});
    return url;
  }
}