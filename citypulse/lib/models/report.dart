import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Report {
  final String id;
  final String title;
  final String description;
  final String category;
  final LatLng location;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? imageUrl;

  Report({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.imageUrl,
  });

  // Firestore'dan veri okuma
  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      location: LatLng(
        (data['location'] as GeoPoint).latitude,
        (data['location'] as GeoPoint).longitude,
      ),
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'Beklemede',
      imageUrl: data['imageUrl'],
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'location': GeoPoint(location.latitude, location.longitude),
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  // Raporu kopyalama ve güncelleme
  Report copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    LatLng? location,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? imageUrl,
  }) {
    return Report(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
