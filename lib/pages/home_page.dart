import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/presence_model.dart';
import 'presence_page.dart';
import 'delivery_page.dart';
import 'calendar_page.dart';
import 'leave_page.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/modern_fab.dart';
import '../utils/constants.dart';
import '../controllers/home_controller.dart';
import '../services/version_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late HomeController _controller;
  String userName = '';
  String companyName = 'SAGANSA';
  PresenceModel? todayPresence;
  List<PresenceModel> previousPresences = [];
  final int initialDisplayCount = 7;
  bool isLoading = false;
  final int _selectedIndex = 0;
  bool _hasActiveLeave = false;
  bool isUserDataLoaded = false;
  PresenceModel? yesterdayPresence;
  bool isStorageStaff = false;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(context);
    _initData();
    
    // Check for app updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService().checkForUpdate(context);
    });
  }

  Future<void> _initData() async {
    setState(() {
      isLoading = true;
    });

    try {
      developer.log('Loading user data from SharedPreferences');
      // Load user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');

      if (userString == null) {
        throw Exception('User data not found');
      }

      final userData = json.decode(userString);
      developer.log('User data loaded: ${userData['name']}');
      final userRoles = List<String>.from(userData['roles'] ?? []);
      final hasStorageStaffRole = userRoles.contains('storage-staff');

      // Load presence data
      developer.log('Loading presence data');
      final presenceData = await _controller.loadPresenceData();
      developer.log('Presence data loaded: ${json.encode(presenceData)}');

      final todayData = presenceData['data']?['today'];
      final previousData = presenceData['data']?['previous'] as List? ?? [];

      developer.log('Today presence: $todayData');
      developer.log('Previous presences: $previousData');

      if (mounted) {
        setState(() {
          userName = userData['name'] ?? '';
          companyName = userData['company']?['name'] ?? 'SAGANSA';
          isStorageStaff = hasStorageStaffRole;
          try {
            todayPresence =
                todayData != null ? PresenceModel.fromJson(todayData) : null;
            yesterdayPresence = previousData.isNotEmpty
                ? PresenceModel.fromJson(previousData[0])
                : null;
            previousPresences = previousData
                .map((item) {
                  try {
                    return PresenceModel.fromJson(item);
                  } catch (e) {
                    developer.log('Error parsing presence item', error: e);
                    return null;
                  }
                })
                .whereType<PresenceModel>()
                .toList();
          } catch (e) {
            developer.log('Error processing presence data', error: e);
            todayPresence = null;
            yesterdayPresence = null;
            previousPresences = [];
          }
          isUserDataLoaded = true;
        });
      }

      // Check active leave
      developer.log('Checking active leave');
      final hasActiveLeave = await _controller.checkActiveLeave();
      if (mounted) {
        setState(() {
          _hasActiveLeave = hasActiveLeave;
        });
      }
      developer.log('Active leave status: $_hasActiveLeave');
    } catch (e) {
      developer.log('Error in _initData',
          error: e, stackTrace: StackTrace.current);
      if (mounted) {
        if (e.toString().contains('User data not found')) {
          _logout();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _initData();
  }

  Future<void> _doPresence() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = todayPresence == null
          ? ApiConstants.checkIn
          : ApiConstants.checkOut;

      final Map<String, dynamic> requestBody = todayPresence == null
          ? {
              'store_id': 137,
              'shift_store_id': 1,
              'status': 1,
              'latitude_in': position.latitude.toString(),
              'longitude_in': position.longitude.toString(),
            }
          : {
              'latitude_out': position.latitude.toString(),
              'longitude_out': position.longitude.toString(),
            };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == AppConstants.statusSuccess) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            todayPresence = PresenceModel.fromJson(responseData['data']);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'])),
          );
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to do presence');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    // Reload presence data after check-in/out
    _loadPresenceData();
  }

  Future<void> _loadPresenceData() async {
    setState(() => isLoading = true);
    try {
      final response = await _controller.loadPresenceData();
      developer.log('Raw API response in HomePage: ${json.encode(response)}',
          name: 'HomePage');

      if (mounted) {
        setState(() {
          if (response['data']?['today'] != null) {
            todayPresence = PresenceModel.fromJson(response['data']['today']);
            developer.log(
                'Today presence set: ${json.encode(response['data']['today'])}',
                name: 'HomePage');
          } else {
            todayPresence = null;
          }

          final previousData = response['data']?['previous'] as List? ?? [];
          previousPresences =
              previousData.map((item) => PresenceModel.fromJson(item)).toList();
          yesterdayPresence =
              previousPresences.isNotEmpty ? previousPresences[0] : null;
        });
      }
    } catch (e) {
      developer.log('Error in _loadPresenceData: $e',
          error: e, name: 'HomePage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _controller.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAllPresenceHistory() {
    if (previousPresences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada riwayat presensi')),
      );
    } else {
      // Gabungkan presensi hari ini dan sebelumnya
      List<PresenceModel> allPresences = [];
      if (todayPresence != null) {
        allPresences.add(todayPresence!);
      }
      allPresences.addAll(previousPresences);

      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CalendarPage(presences: allPresences),
      ));
    }
  }

  Widget _buildPresenceCard(PresenceModel presence) {
    final checkInDateTime = _controller.splitDateTime(presence.checkIn);
    final checkOutDateTime = presence.checkOut != null
        ? _controller.splitDateTime(presence.checkOut!)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Store dan Shift info di tengah
            Text(presence.store,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center),
            Text(presence.shiftStore,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Check In Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Check In',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: presence
                              .getStatusColor(presence.checkInStatus)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          presence.getStatusText(presence.checkInStatus),
                          style: TextStyle(
                            color:
                                presence.getStatusColor(presence.checkInStatus),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14),
                          const SizedBox(width: 4),
                          Text(checkInDateTime['date']!),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14),
                          const SizedBox(width: 4),
                          Text(checkInDateTime['time']!),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 80,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                // Check Out Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Check Out',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        if (checkOutDateTime != null) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: presence
                                  .getStatusColor(presence.checkOutStatus ?? '')
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              presence
                                  .getStatusText(presence.checkOutStatus ?? ''),
                              style: TextStyle(
                                color: presence.getStatusColor(
                                    presence.checkOutStatus ?? ''),
                                fontSize: 12,
                              ),
                            ),
                          );
                        } else {
                          // Tampilkan status tidak_absen jika checkOutStatus ada
                          String status = presence.checkOutStatus ?? '-';
                          if (status == 'tidak_absen') {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: presence
                                    .getStatusColor('tidak_absen')
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                presence.getStatusText('tidak_absen'),
                                style: TextStyle(
                                  color: presence.getStatusColor('tidak_absen'),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text('-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                )),
                          );
                        }
                      }),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.calendar_today, size: 14),
                          const SizedBox(width: 4),
                          Text(checkOutDateTime?['date'] ?? '-'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.access_time, size: 14),
                          const SizedBox(width: 4),
                          Text(checkOutDateTime?['time'] ?? '-'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPresencePage() async {
    // Langsung navigasi ke PresencePage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PresencePage(
          isCheckIn: todayPresence == null,
        ),
      ),
    );

    // Refresh data jika ada perubahan
    if (result == true) {
      await _loadPresenceData();
      setState(() {});
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        // Sudah di home, tidak perlu navigasi
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LeavePage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarPage(
              presences: [
                ...previousPresences,
                if (todayPresence != null) todayPresence!
              ],
            ),
          ),
        );
        break;
    }
  }

  Widget _buildPresenceSection() {
    return todayPresence != null
        ? _buildPresenceCard(todayPresence!)
        : Card(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada presensi untuk hari ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Silakan lakukan presensi dengan menekan tombol di bawah',
                    textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => InkWell(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset(
                'assets/images/new-logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                color: Theme.of(context).primaryColor,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
            Text(
              companyName,
              style: TextStyle(fontSize: 12, color: Colors.grey[300]),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
             DrawerHeader(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF121212),
                    child: Image.asset(
                      'assets/images/new-logo.png',
                      width: 32,
                      height: 32,
                      color: Theme.of(context).primaryColor,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    companyName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Beranda'),
              onTap: () => Navigator.pop(context),
            ),
            if (isStorageStaff)
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Pengiriman Online'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DeliveryPage()),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Pengaturan'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementasi halaman pengaturan
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Bantuan'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementasi halaman bantuan
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ya'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _logout();
                }
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPresenceSection(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Presensi:',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _showAllPresenceHistory,
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                previousPresences.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            previousPresences.length > initialDisplayCount
                                ? initialDisplayCount
                                : previousPresences.length,
                        itemBuilder: (context, index) {
                          return _buildPresenceCard(previousPresences[index]);
                        },
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 200, // Memberikan tinggi tetap
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada riwayat presensi',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_hasActiveLeave ||
              (todayPresence != null && todayPresence!.checkOut != null))
          ? null // Sembunyikan FAB jika ada leave aktif atau sudah check out
          : CustomFAB(
              onPressed: _navigateToPresencePage,
              icon:
                  todayPresence == null ? Icons.fingerprint : Icons.fingerprint,
              tooltip: todayPresence == null ? 'Check In' : 'Check Out',
            ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        presences: [
          ...previousPresences,
          if (todayPresence != null) todayPresence!
        ],
      ),
    );
  }
}
