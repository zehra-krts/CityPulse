import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../theme/app_theme.dart';
import '../providers/report_provider.dart';
import '../models/report.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:loading_animation_widget/loading_animation_widget.dart'
    as loading_animation_widget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  Position? _currentPosition;
  static const double _searchRadius = 5.0; // 5 km yarıçap

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izinleri reddedildi');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izinleri kalıcı olarak reddedildi');
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Yakındaki raporları getir
      await _fetchNearbyReports();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum alınamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchNearbyReports() async {
    try {
      if (_currentPosition == null) return;

      final reportProvider = context.read<ReportProvider>();
      await reportProvider.fetchNearbyReports(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );

      if (mounted) {
        _updateMarkers();
      }
    } catch (e) {
      print('Yakındaki raporlar getirilirken hata oluştu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Raporlar getirilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateMarkers() {
    if (!mounted) return;

    final markers = <Marker>{};
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final reportProvider = context.read<ReportProvider>();

    print(
        'Güncel rapor sayısı: ${reportProvider.nearbyReports.length}'); // Debug için

    // Kullanıcının konumunu ekle
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Konumunuz'),
        ),
      );
    }

    // Raporları ekle
    for (final report in reportProvider.nearbyReports) {
      print(
          'Rapor ekleniyor - ID: ${report.id}, Kullanıcı ID: ${report.userId}'); // Debug için
      final isUserReport = report.userId == currentUserId;

      // Duruma göre renk belirle
      double markerHue = _getStatusHue(report.status);

      // Kullanıcının kendi raporları için özel işaretleme
      if (isUserReport) {
        // Kullanıcının kendi raporları için daha belirgin marker
        markers.add(
          Marker(
            markerId: MarkerId(report.id),
            position: report.location,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(
              title: '${report.title} (Sizin Raporunuz)',
              snippet: '${report.category} - ${report.status}',
              onTap: () => _showReportDetails(report),
            ),
            // Kullanıcının kendi raporları için daha büyük marker
            flat: false,
            anchor: const Offset(0.5, 1.0),
          ),
        );
      } else {
        // Diğer kullanıcıların raporları
        markers.add(
          Marker(
            markerId: MarkerId(report.id),
            position: report.location,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(
              title: report.title,
              snippet: '${report.category} - ${report.status}',
              onTap: () => _showReportDetails(report),
            ),
          ),
        );
      }
    }

    print('Toplam marker sayısı: ${markers.length}'); // Debug için

    setState(() {
      _markers = markers;
    });
  }

  // Duruma göre marker rengi belirle
  double _getStatusHue(String status) {
    switch (status.toLowerCase()) {
      case 'beklemede':
        return BitmapDescriptor.hueOrange;
      case 'işlemde':
        return BitmapDescriptor.hueBlue;
      case 'tamamlandı':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  void _showReportDetails(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(report.status),
                    ),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                      color: _getStatusColor(report.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  report.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kategori: ${report.category}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Oluşturulma: ${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'beklemede':
        return Colors.orange;
      case 'işlemde':
        return Colors.blue;
      case 'tamamlandı':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_currentPosition == null) {
      return const Center(
        child: Text('Konum alınamadı'),
      );
    }

    final reportProvider = context.watch<ReportProvider>();
    final reportCount = reportProvider.nearbyReports.length;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _updateMarkers(); // Harita oluşturulduğunda markerları güncelle
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Yakınınızdaki $reportCount rapor bulundu',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Renk açıklaması
                  Row(
                    children: [
                      _buildLegendItem('Beklemede', Colors.orange),
                      const SizedBox(width: 16),
                      _buildLegendItem('İşlemde', Colors.blue),
                      const SizedBox(width: 16),
                      _buildLegendItem('Tamamlandı', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kendi raporlarınız "(Sizin Raporunuz)" olarak işaretlenmiştir',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
