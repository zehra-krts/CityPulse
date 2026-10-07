import 'package:flutter/foundation.dart';
import '../models/report.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ReportProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcının kendi raporları
  List<Report> _userReports = [];
  // Yakındaki tüm raporlar
  List<Report> _nearbyReports = [];

  // Kullanıcının kendi raporlarını getir
  List<Report> get userReports => _userReports;
  // Yakındaki tüm raporları getir
  List<Report> get nearbyReports => _nearbyReports;

  ReportProvider() {
    // Kullanıcı değişikliklerini dinle
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        print('Kullanıcı giriş yaptı: ${user.uid}'); // Debug için
        await fetchUserReports();
      } else {
        print('Kullanıcı çıkış yaptı'); // Debug için
        _userReports = [];
        notifyListeners();
      }
    });
  }

  // Kullanıcının kendi raporlarını getir
  Future<void> fetchUserReports() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('Kullanıcı ID bulunamadı'); // Debug için
        _userReports = [];
        notifyListeners();
        return;
      }

      print(
          'Kullanıcı raporları getiriliyor. Kullanıcı ID: $userId'); // Debug için

      // Firestore'dan kullanıcının raporlarını getir
      final snapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .get();

      _userReports = snapshot.docs.map((doc) {
        final report = Report.fromFirestore(doc);
        print(
            'Rapor bulundu - ID: ${report.id}, Kullanıcı ID: ${report.userId}'); // Debug için
        return report;
      }).toList();

      // Raporları createdAt'e göre sırala (client-side)
      _userReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('Toplam ${_userReports.length} rapor bulundu'); // Debug için
      notifyListeners();
    } catch (e) {
      print('Kullanıcı raporları getirilirken hata oluştu: $e');
      _userReports = [];
      notifyListeners();
    }
  }

  // Yakındaki raporları getir
  Future<void> fetchNearbyReports(
      double latitude, double longitude, double radiusInKm) async {
    try {
      // Tüm raporları getir
      final snapshot = await _firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .get();

      final allReports = snapshot.docs.map((doc) {
        final report = Report.fromFirestore(doc);
        print(
            'Yakındaki Rapor ID: ${report.id}, Kullanıcı ID: ${report.userId}'); // Debug için
        return report;
      }).toList();

      // Belirtilen yarıçap içindeki raporları filtrele
      _nearbyReports = allReports.where((report) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          report.location.latitude,
          report.location.longitude,
        );
        return distance <= radiusInKm;
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Yakındaki raporlar getirilirken hata oluştu: $e');
      _nearbyReports = [];
      notifyListeners();
    }
  }

  // İki nokta arasındaki mesafeyi hesapla (km cinsinden)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Yeni rapor ekle
  Future<void> addReport(Report report) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      print('Yeni rapor ekleniyor. Kullanıcı ID: $userId'); // Debug için

      // Raporu Firestore'a ekle
      final docRef = await _firestore.collection('reports').add({
        'title': report.title,
        'description': report.description,
        'category': report.category,
        'location':
            GeoPoint(report.location.latitude, report.location.longitude),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': report.status,
        if (report.imageUrl != null) 'imageUrl': report.imageUrl,
      });

      print('Rapor Firestore\'a eklendi. Rapor ID: ${docRef.id}'); // Debug için

      // Yeni raporu oluştur
      final newReport = Report(
        id: docRef.id,
        title: report.title,
        description: report.description,
        category: report.category,
        location: report.location,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: report.status,
        imageUrl: report.imageUrl,
      );

      // Listeleri güncelle
      _userReports.add(newReport);
      _nearbyReports.add(newReport);

      print(
          'Rapor listelere eklendi. Toplam rapor sayısı: ${_userReports.length}'); // Debug için
      notifyListeners();
    } catch (e) {
      print('Rapor eklenirken hata oluştu: $e');
      rethrow;
    }
  }

  // Rapor güncelle
  Future<void> updateReport(Report report) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');
      if (report.userId != userId)
        throw Exception('Bu raporu güncelleme yetkiniz yok');

      print('Rapor güncelleniyor. Rapor ID: ${report.id}'); // Debug için

      // Firestore'da raporu güncelle
      await _firestore.collection('reports').doc(report.id).update({
        'title': report.title,
        'description': report.description,
        'category': report.category,
        'location':
            GeoPoint(report.location.latitude, report.location.longitude),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': report.status,
        if (report.imageUrl != null) 'imageUrl': report.imageUrl,
      });

      // Kullanıcının kendi raporlarını güncelle
      final index = _userReports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _userReports[index] = report;
      }

      // Yakındaki raporları da güncelle
      final nearbyIndex = _nearbyReports.indexWhere((r) => r.id == report.id);
      if (nearbyIndex != -1) {
        _nearbyReports[nearbyIndex] = report;
      }

      print(
          'Rapor güncellendi. Toplam rapor sayısı: ${_userReports.length}'); // Debug için
      notifyListeners();
    } catch (e) {
      print('Rapor güncellenirken hata oluştu: $e');
      rethrow;
    }
  }

  // Rapor sil
  Future<void> deleteReport(String reportId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      print('Rapor siliniyor. Rapor ID: $reportId'); // Debug için

      // Raporun kullanıcıya ait olduğunu kontrol et
      final report = _userReports.firstWhere((r) => r.id == reportId);
      if (report.userId != userId)
        throw Exception('Bu raporu silme yetkiniz yok');

      // Firestore'dan raporu sil
      await _firestore.collection('reports').doc(reportId).delete();

      // Listeleri güncelle
      _userReports.removeWhere((report) => report.id == reportId);
      _nearbyReports.removeWhere((report) => report.id == reportId);

      print(
          'Rapor silindi. Kalan rapor sayısı: ${_userReports.length}'); // Debug için
      notifyListeners();
    } catch (e) {
      print('Rapor silinirken hata oluştu: $e');
      rethrow;
    }
  }
}
