import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'dart:async';
import '../theme/app_theme.dart';
import '../providers/report_provider.dart';
import '../models/report.dart';
import 'package:uuid/uuid.dart';
import '../screens/profile_screen.dart';
import 'package:geocoding/geocoding.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  File? _image;
  LatLng? _selectedLocation;
  bool _isLoading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  final List<String> _categories = [
    'Çöp',
    'Kaldırım',
    'Aydınlatma',
    'Trafik',
    'Sokak Hayvanları',
    'Güvenlik',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16.w),
                        child: Text(
                          'Konum Seç',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: () async {
                          final position = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                          );
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(position.latitude, position.longitude),
                              15,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _selectedLocation ?? const LatLng(38.4192, 27.1287),
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      controller.setMapStyle('''
                        [
                          {
                            "featureType": "poi",
                            "elementType": "labels",
                            "stylers": [
                              {
                                "visibility": "off"
                              }
                            ]
                          }
                        ]
                      ''');
                    },
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onCameraMove: (position) {
                      // Harita hareket ederken marker'ı güncelle
                      setState(() {
                        _markers = {
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: position.target,
                            draggable: true,
                            onDragEnd: (newPosition) {
                              setState(() {
                                _selectedLocation = newPosition;
                              });
                            },
                          ),
                        };
                        _selectedLocation = position.target;
                      });
                    },
                    onTap: (position) {
                      setState(() {
                        _markers = {
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: position,
                            draggable: true,
                            onDragEnd: (newPosition) {
                              setState(() {
                                _selectedLocation = newPosition;
                              });
                            },
                          ),
                        };
                        _selectedLocation = position;
                      });
                    },
                  ),
                  // Arama çubuğu
                  Positioned(
                    top: 16.h,
                    left: 16.w,
                    right: 16.w,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Konum ara...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        onSubmitted: (value) async {
                          try {
                            List<Location> locations =
                                await locationFromAddress(value);
                            if (locations.isNotEmpty) {
                              final location = locations.first;
                              final latLng = LatLng(
                                location.latitude,
                                location.longitude,
                              );
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(latLng, 15),
                              );
                              setState(() {
                                _markers = {
                                  Marker(
                                    markerId:
                                        const MarkerId('selected_location'),
                                    position: latLng,
                                    draggable: true,
                                    onDragEnd: (newPosition) {
                                      setState(() {
                                        _selectedLocation = newPosition;
                                      });
                                    },
                                  ),
                                };
                                _selectedLocation = latLng;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Konum bulunamadı'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16.h,
                    left: 16.w,
                    right: 16.w,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: const Text('Konumu Seç'),
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

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Konum servislerinin durumunu kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı');
      }

      // Konum izinlerini kontrol et
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

      // Son bilinen konumu al
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        setState(() {
          _selectedLocation = LatLng(
            lastKnownPosition.latitude,
            lastKnownPosition.longitude,
          );
        });
      }

      // Daha doğru konum için güncel konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (lastKnownPosition != null) {
            return lastKnownPosition;
          }
          throw TimeoutException('Konum alınamadı, lütfen tekrar deneyin');
        },
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum alınamadı: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir konum seçin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final report = Report(
        id: const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        location: _selectedLocation!,
        userId: 'current_user_id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'Beklemede',
        imageUrl: _image != null ? _image!.path : null,
      );

      context.read<ReportProvider>().addReport(report);

      // Form alanlarını temizle
      _titleController.clear();
      _descriptionController.clear();
      _categoryController.clear();
      setState(() {
        _image = null;
        _selectedLocation = null;
      });

      // Başarı mesajını göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şikayet başarıyla oluşturuldu'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Profil sayfasına yönlendir
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Şikayet/Öneri'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.h,
            bottom: 100.h,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir başlık girin';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir açıklama girin';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  value: _categories.first,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _categoryController.text = newValue;
                    }
                  },
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Galeriden Seç'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Fotoğraf Çek'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_image != null) ...[
                  SizedBox(height: 16.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(
                      _image!,
                      height: 200.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Theme.of(context).primaryColor),
                              SizedBox(width: 8.w),
                              Text(
                                'Konum',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showLocationPicker,
                            icon: const Icon(Icons.map),
                            label: const Text('Haritadan Seç'),
                          ),
                        ],
                      ),
                      if (_selectedLocation != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          'Enlem: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        Text(
                          'Boylam: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ],
                      if (_isLoading) ...[
                        SizedBox(height: 8.h),
                        Center(
                          child: SizedBox(
                            width: 16.w,
                            height: 16.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      minimumSize: Size(double.infinity, 50.h),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Şikayeti Gönder',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
