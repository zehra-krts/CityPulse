import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../theme/app_theme.dart';
import '../providers/report_provider.dart';
import '../models/report.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  @override
  void initState() {
    super.initState();
    _setupReportsListener();
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    super.dispose();
  }

  void _setupReportsListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      // Raporları güncelle
      context.read<ReportProvider>().fetchUserReports();
    });
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çıkış yapılırken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, child) {
          final userReports = reportProvider.userReports;

          if (userReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Henüz hiç şikayet/öneri oluşturmadınız.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/report');
                    },
                    child: const Text('Yeni Şikayet/Öneri Oluştur'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: userReports.length,
            itemBuilder: (context, index) {
              final report = userReports[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(report.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.description),
                      const SizedBox(height: 4),
                      Text(
                        'Durum: ${report.status}',
                        style: TextStyle(
                          color: _getStatusColor(report.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        try {
                          await reportProvider.deleteReport(report.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rapor başarıyla silindi'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Rapor silinirken hata oluştu: $e'),
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Sil'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Beklemede':
        return Colors.orange;
      case 'İşlemde':
        return Colors.blue;
      case 'Tamamlandı':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class ReportDetailScreen extends StatelessWidget {
  final Report report;

  const ReportDetailScreen({super.key, required this.report});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şikayet Detayı'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.imageUrl != null)
              Container(
                height: 250.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(report.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(report.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20.r),
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
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Açıklama',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          report.description,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detaylar',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildDetailRow(
                          'Kategori',
                          report.category,
                          Icons.category,
                        ),
                        SizedBox(height: 8.h),
                        _buildDetailRow(
                          'Oluşturulma Tarihi',
                          '${report.createdAt.day}/${report.createdAt.month}/${report.createdAt.year}',
                          Icons.calendar_today,
                        ),
                        SizedBox(height: 8.h),
                        _buildDetailRow(
                          'Son Güncelleme',
                          '${report.updatedAt.day}/${report.updatedAt.month}/${report.updatedAt.year}',
                          Icons.update,
                        ),
                        SizedBox(height: 8.h),
                        _buildDetailRow(
                          'Konum',
                          '${report.location.latitude.toStringAsFixed(6)}, ${report.location.longitude.toStringAsFixed(6)}',
                          Icons.location_on,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20.sp,
          color: Colors.grey[600],
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
