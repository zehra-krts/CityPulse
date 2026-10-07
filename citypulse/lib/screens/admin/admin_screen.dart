import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart'
    as loading_animation_widget;
import 'dart:math';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  List<Report> _allReports = [];
  bool _isLoading = true;
  String _selectedStatus = 'Tümü';
  String _selectedCategory = 'Tümü';
  bool _showMap = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Position? _currentPosition;
  late TabController _tabController;

  final List<String> _statusOptions = [
    'Tümü',
    'Beklemede',
    'İşlemde',
    'Tamamlandı'
  ];
  final List<String> _categoryOptions = [
    'Tümü',
    'Altyapı',
    'Çevre',
    'Güvenlik',
    'Ulaşım',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentLocation();
    _fetchAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      _updateMapMarkers();
    } catch (e) {
      print('Konum alınamadı: $e');
    }
  }

  Future<void> _fetchAllReports() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .get();

      _allReports =
          snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList();

      setState(() => _isLoading = false);
      _updateMapMarkers();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Raporlar yüklenirken hata: $e')),
        );
      }
    }
  }

  void _updateMapMarkers() {
    if (!mounted) return;

    final markers = <Marker>{};
    final filteredReports = _filteredReports;

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
    for (final report in filteredReports) {
      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: report.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _getStatusHue(report.status)),
          infoWindow: InfoWindow(
            title: report.title,
            snippet: '${report.category} - ${report.status}',
            onTap: () => _showReportDetails(report),
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

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

  List<Report> get _filteredReports {
    return _allReports.where((report) {
      bool statusMatch =
          _selectedStatus == 'Tümü' || report.status == _selectedStatus;
      bool categoryMatch =
          _selectedCategory == 'Tümü' || report.category == _selectedCategory;
      return statusMatch && categoryMatch;
    }).toList();
  }

  Future<void> _updateReportStatus(Report report, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Yerel listeyi güncelle
      final index = _allReports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _allReports[index] = report.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        setState(() {});
        _updateMapMarkers(); // Harita markerlarını güncelle
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rapor durumu güncellendi: $newStatus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme hatası: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReportDetails(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(report.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _getStatusColor(report.status)),
                          ),
                          child: Text(
                            report.status,
                            style: TextStyle(
                              color: _getStatusColor(report.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Kategori', report.category),
                    _buildInfoRow('Tarih',
                        '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}'),
                    _buildInfoRow('Konum',
                        '${report.location.latitude.toStringAsFixed(4)}, ${report.location.longitude.toStringAsFixed(4)}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Açıklama:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Durum Güncelle:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusButton(
                              report, 'Beklemede', Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusButton(
                              report, 'İşlemde', Colors.blue),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusButton(
                              report, 'Tamamlandı', Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusButton(Report report, String status, Color color) {
    final isCurrentStatus = report.status == status;
    return ElevatedButton(
      onPressed: () => _updateReportStatus(report, status),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrentStatus ? color : color.withOpacity(0.1),
        foregroundColor: isCurrentStatus ? Colors.white : color,
        elevation: isCurrentStatus ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontWeight: isCurrentStatus ? FontWeight.bold : FontWeight.normal,
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
    final filteredReports = _filteredReports;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllReports,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik kartları
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Toplam', _allReports.length.toString(), Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Beklemede',
                        _allReports
                            .where((r) => r.status == 'Beklemede')
                            .length
                            .toString(),
                        Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'İşlemde',
                        _allReports
                            .where((r) => r.status == 'İşlemde')
                            .length
                            .toString(),
                        Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard(
                        'Tamamlandı',
                        _allReports
                            .where((r) => r.status == 'Tamamlandı')
                            .length
                            .toString(),
                        Colors.green)),
              ],
            ),
          ),
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: 'Raporlar'),
                Tab(icon: Icon(Icons.map), text: 'Harita'),
              ],
            ),
          ),
          // Tab içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Raporlar tab'ı
                _buildReportsTab(filteredReports),
                // Harita tab'ı
                _buildMapTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab(List<Report> reports) {
    return Column(
      children: [
        // Filtreler
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Durum',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                    _updateMapMarkers();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _categoryOptions.map((category) {
                    return DropdownMenuItem(
                        value: category, child: Text(category));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _updateMapMarkers();
                  },
                ),
              ),
            ],
          ),
        ),
        // Raporlar listesi
        Expanded(
          child: _isLoading
              ? Center(
                  child: loading_animation_widget.LoadingAnimationWidget
                      .staggeredDotsWave(
                    color: Theme.of(context).primaryColor,
                    size: 50,
                  ),
                )
              : reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Rapor bulunamadı',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return _buildReportCard(report);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMapTab() {
    if (_currentPosition == null) {
      return Container(
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Konum alınamadı',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Harita görüntülemek için konum izni gerekli',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Ana harita
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 12,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _updateMapMarkers();
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // Kendi butonumuzu kullanacağız
          zoomControlsEnabled: false, // Kendi kontrollerimizi kullanacağız
          mapToolbarEnabled: false,
          compassEnabled: true,
          buildingsEnabled: true,
          trafficEnabled: false,
          indoorViewEnabled: true,
          onCameraMove: (position) {
            // Harita hareket ederken markerları güncelle
          },
          onCameraIdle: () {
            // Harita durduğunda markerları güncelle
            _updateMapMarkers();
          },
        ),

        // Üst bilgi kartı
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.map, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Harita Görünümü',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_markers.length - 1} rapor', // -1 çünkü kullanıcı konumu da var
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildLegendItem('Beklemede', Colors.orange),
                    const SizedBox(width: 16),
                    _buildLegendItem('İşlemde', Colors.blue),
                    const SizedBox(width: 16),
                    _buildLegendItem('Tamamlandı', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Sağ taraftaki harita kontrolleri
        Positioned(
          top: 120,
          right: 16,
          child: Column(
            children: [
              _buildMapControlButton(
                icon: Icons.my_location,
                onPressed: () {
                  if (_mapController != null && _currentPosition != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude),
                      ),
                    );
                  }
                },
                tooltip: 'Konumuma Git',
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.zoom_in,
                onPressed: () {
                  if (_mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.zoomIn(),
                    );
                  }
                },
                tooltip: 'Yakınlaştır',
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.zoom_out,
                onPressed: () {
                  if (_mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.zoomOut(),
                    );
                  }
                },
                tooltip: 'Uzaklaştır',
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.fit_screen,
                onPressed: () {
                  if (_mapController != null && _markers.isNotEmpty) {
                    _fitAllMarkers();
                  }
                },
                tooltip: 'Tüm Raporları Göster',
              ),
            ],
          ),
        ),

        // Alt bilgi kartı
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Harita Kullanımı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Marker\'lara tıklayarak rapor detaylarını görüntüleyebilirsiniz\n'
                  '• Sağ taraftaki butonlarla haritayı kontrol edebilirsiniz\n'
                  '• Filtreler harita üzerindeki marker\'ları da etkiler',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty) return;

    // Kullanıcı konumu hariç tüm markerları al
    final reportMarkers = _markers
        .where((marker) => marker.markerId.value != 'current_location')
        .toList();

    if (reportMarkers.isEmpty) return;

    // Tüm markerları içeren bounds hesapla
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in reportMarkers) {
      minLat = min(minLat, marker.position.latitude);
      maxLat = max(maxLat, marker.position.latitude);
      minLng = min(minLng, marker.position.longitude);
      maxLng = max(maxLng, marker.position.longitude);
    }

    // Padding ekle
    const padding = 0.01; // Yaklaşık 1km
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // 50px padding
    );
  }

  Widget _buildReportCard(Report report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  report.category,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(report.status)),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                      color: _getStatusColor(report.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Açıklama:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  report.description,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusButton(
                          report, 'Beklemede', Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusButton(report, 'İşlemde', Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatusButton(
                          report, 'Tamamlandı', Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
