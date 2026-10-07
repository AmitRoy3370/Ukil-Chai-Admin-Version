import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:http/http.dart' as http;
import 'package:advocatechaiadmin/Utils/BaseURL.dart' as baseURL;

import '../Utils/AdvocateSpeciality.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController(); // ✅ NEW
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationTextController = TextEditingController();

  bool _showPassword = false;

  lat_lng.LatLng? _devicePosition;
  lat_lng.LatLng? _selectedPosition;
  String? _selectedPlaceName;
  List<Marker> _markers = [];
  bool showForm = false;
  File? pickedImage;
  Uint8List? webImageBytes;
  double lattitude = 0.0;
  double longititude = 0.0;

  final MapController mapController = MapController();

  Stream<Position>? _positionStream;

  List<AdvocateSpeciality> selectedDistricts = [];

  final List<String> bangladeshDistricts = AdvocateSpeciality.values
      .map((e) => e.name)
      .toList();

  // ============ RESPONSIVE HELPERS ============
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  double get _formHeight {
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isDesktop) return screenHeight * 0.85;
    if (_isTablet) return screenHeight * 0.80;
    if (screenHeight < 700) return screenHeight * 0.95;
    return screenHeight * 0.90;
  }

  double get _horizontalPadding {
    if (_isDesktop) return 24;
    if (_isTablet) return 20;
    return 14;
  }

  double get _maxContentWidth {
    if (_isDesktop) return 500;
    if (_isTablet) return 600;
    return double.infinity;
  }

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    fullNameController.dispose(); // ✅ NEW
    passwordController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationTextController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location service")),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied forever")),
        );
      }
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    );
    _updateDevicePosition(position);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );

    _positionStream!.listen((Position position) {
      _updateDevicePosition(position);
    });
  }

  Future<void> _updateDevicePosition(Position position) async {
    lat_lng.LatLng newPos = lat_lng.LatLng(
      position.latitude,
      position.longitude,
    );
    String placeName = await getAddressFromLatLng(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _devicePosition = newPos;
      if (_selectedPosition == null) {
        _selectedPosition = newPos;
        _selectedPlaceName = placeName;
        lattitude = position.latitude;
        longititude = position.longitude;
        locationTextController.text = placeName;
      }
      _updateMarkers();
    });

    if (_selectedPosition == newPos) {
      mapController.move(newPos, 15.0);
    }
  }

  void _updateMarkers() {
    _markers = [];
    if (_devicePosition != null) {
      _markers.add(
        Marker(
          width: 80,
          height: 80,
          point: _devicePosition!,
          child: const Icon(Icons.my_location, color: Colors.red, size: 40),
        ),
      );
    }
    if (_selectedPosition != null && _selectedPosition != _devicePosition) {
      _markers.add(
        Marker(
          width: 80,
          height: 80,
          point: _selectedPosition!,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      );
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'AdvocateChaiApp/1.0 (your-email@example.com)'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
    } catch (e) {
      if (kDebugMode) print('Geocoding error: $e');
    }
    return 'Lat: $lat, Lng: $lng';
  }

  Future<void> searchPlace() async {
    String query = searchController.text.trim();
    if (query.isEmpty) return;

    lat_lng.LatLng? pos;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'AdvocateChaiApp/1.0 (your-email@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lng = double.parse(data[0]['lon']);
          lattitude = lat;
          longititude = lng;
          pos = lat_lng.LatLng(lat, lng);
          String name = data[0]['display_name'];
          setState(() {
            _selectedPosition = pos;
            _selectedPlaceName = name;
            locationTextController.text = _selectedPlaceName!;
            _updateMarkers();
          });
          mapController.move(pos, 15.0);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Search error: $e');
    }

    if (pos == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No results found")),
      );
    }
  }

  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Select from gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take from camera'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    XFile? file = await ImagePicker().pickImage(source: source);
    if (file != null) {
      if (kIsWeb) {
        webImageBytes = await file.readAsBytes();
      } else {
        pickedImage = File(file.path);
      }
      if (mounted) setState(() {});
    }
  }

  void showDistrictDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Select Specialist",
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: bangladeshDistricts.map((district) {
                    final isSelected = selectedDistricts
                        .any((s) => s.name == district);
                    return CheckboxListTile(
                      title: Text(district),
                      value: isSelected,
                      onChanged: (value) {
                        dialogSetState(() {
                          if (value == true) {
                            selectedDistricts.add(
                              AdvocateSpecialityExt.fromApi(district),
                            );
                          } else {
                            selectedDistricts
                                .removeWhere((s) => s.name == district);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text("Done", style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============ SNACK HELPER ============
  void _showSnack(String message, [Color color = Colors.orange]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // ============ SUBMIT FORM ============
  // NOTE: This is only a REQUEST to become admin.
  // No auto-login, no token saving, no navigation to home.
  Future<void> _submitForm() async {
    try {
      final uri = Uri.parse("${baseURL.Urls().baseURL}auth/register");

      if (fullNameController.text.isEmpty) {
        _showSnack("Please enter full name");
        return;
      } else if (nameController.text.isEmpty) {
        _showSnack("Please enter user name");
        return;
      } else if (passwordController.text.isEmpty) {
        _showSnack("Please enter password");
        return;
      } else if (emailController.text.isEmpty) {
        _showSnack("Please enter email");
        return;
      } else if (phoneController.text.isEmpty) {
        _showSnack("Please enter phone");
        return;
      } else if (locationTextController.text.isEmpty) {
        _showSnack("Please enter location");
        return;
      } else if (selectedDistricts.isEmpty) {
        _showSnack("Please select at least one specialist area");
        return;
      }

      var request = http.MultipartRequest("POST", uri);

      request.fields["name"] = nameController.text.trim();
      request.fields["FullName"] = fullNameController.text.trim(); // ✅ NEW
      request.fields["password"] = passwordController.text.trim();
      request.fields["profileImageId"] = "profileImageId";

      if (kIsWeb && webImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webImageBytes!,
            filename: '${nameController.text.trim()}.png',
            contentType: http.MediaType('image', 'png'),
          ),
        );
      } else if (!kIsWeb && pickedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("file", pickedImage!.path),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(responseBody);

        // ✅ Backend returns token + userId, but we DO NOT save them
        // because this is only a REQUEST for admin role.
        final String token = decoded["token"];
        final String userId = decoded["userId"];

        if (kDebugMode) {
          print("Admin request created for userId: $userId");
        }

        // -------- Add Contact Info (using token only for this request) --------
        if (emailController.text.isNotEmpty ||
            phoneController.text.isNotEmpty) {
          final url = Uri.parse(
            "${baseURL.Urls().baseURL}user/contact-info/add?userId=$userId",
          );

          await http.post(
            url,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "userId": userId,
              "email": emailController.text.isNotEmpty
                  ? emailController.text.trim()
                  : null,
              "phone": phoneController.text.isNotEmpty
                  ? phoneController.text.trim()
                  : null,
            }),
          );
        }

        // -------- Add Location --------
        final locationUrl = "${baseURL.Urls().baseURL}userLocation/add";
        await http.post(
          Uri.parse(locationUrl),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "userId": userId,
            "locationName": locationTextController.text.trim(),
            "lattitude": lattitude,
            "longitude": longititude,
          }),
        );

        // -------- Send Admin Join Request --------
        final adminJoinResponse = await http.post(
          Uri.parse("${baseURL.Urls().baseURL}adminJoinRequest/add/$userId"),
          headers: {
            'content-type': 'application/json',
            'Authorization': "Bearer $token",
          },
          body: jsonEncode({
            "userId": userId,
            "advocateSpeciality":
                selectedDistricts.map((e) => e.name).toList(),
          }),
        );

        if (adminJoinResponse.statusCode == 200 ||
            adminJoinResponse.statusCode == 201) {
          // Reset form
          setState(() {
            showForm = false;
          });

          nameController.clear();
          fullNameController.clear(); // ✅ NEW
          passwordController.clear();
          emailController.clear();
          phoneController.clear();
          locationTextController.clear();
          pickedImage = null;
          webImageBytes = null;
          selectedDistricts.clear();

          // Show success message — user must WAIT for approval
          _showSnack(
            "🎉 Admin join request sent successfully! "
            "Please wait for approval from an existing authority.",
            Colors.green,
          );

          if (kDebugMode) {
            print("✅ Admin join request sent. Awaiting approval.");
          }
        } else {
          _showSnack("Failed to send admin join request", Colors.red);
        }
      } else {
        if (kDebugMode) {
          print("Register failed: $responseBody");
        }
        _showSnack("Registration failed", Colors.red);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error: $e");
      }
      _showSnack(e.toString(), Colors.red);
    }
  }

  // ============ UI COMPONENTS ============

  Widget _buildOpenFormButton() {
    return GestureDetector(
      onTap: () => setState(() => showForm = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(showForm ? 0.0 : 1.0),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 18 : 20,
            vertical: _isMobile ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1 + (value * 0.1),
                    child: Container(
                      padding: EdgeInsets.all(_isMobile ? 6 : 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: Colors.blue,
                        size: _isMobile ? 18 : 20,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: _isMobile ? 8 : 12),
              Text(
                'অ্যাডমিন রেজিস্ট্রেশন',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: _isMobile ? 14 : 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: _isMobile ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedForm() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      bottom: showForm ? 0 : -MediaQuery.of(context).size.height,
      left: 0,
      right: 0,
      height: _formHeight,
      child: IgnorePointer(
        ignoring: !showForm,
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: showForm ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 100),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxContentWidth),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy > 10) {
                          setState(() => showForm = false);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _buildFormHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom + 20,
                          left: _horizontalPadding,
                          right: _horizontalPadding,
                          top: 16,
                        ),
                        child: Column(
                          children: [
                            // ✅ NEW: Full Name field
                            _buildFormField(
                              controller: fullNameController,
                              label: "পূর্ণ নাম",
                              icon: Icons.badge_outlined,
                              hint: "আপনার পূর্ণ নাম লিখুন",
                            ),
                            const SizedBox(height: 14),
                            // User name (used as login handle)
                            _buildFormField(
                              controller: nameController,
                              label: "ইউজার নেম",
                              icon: Icons.person_outline,
                              hint: "ইউনিক ইউজার নেম দিন",
                            ),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: emailController,
                              label: "ইমেইল",
                              icon: Icons.email_outlined,
                              hint: "আপনার ইমেইল ঠিকানা",
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: phoneController,
                              label: "মোবাইল নম্বর",
                              icon: Icons.phone_outlined,
                              hint: "০১XXXXXXXXX",
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),
                            _buildPasswordField(),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: locationTextController,
                              label: "লোকেশন",
                              icon: Icons.location_on_outlined,
                              hint: "মানচিত্র থেকে সিলেক্ট করুন",
                              readOnly: true,
                            ),
                            const SizedBox(height: 18),
                            _buildSpecialistSection(),
                            const SizedBox(height: 18),
                            _buildImagePicker(),
                            const SizedBox(height: 24),
                            _buildSubmitButton(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 14 : 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_isMobile ? 8 : 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.blue,
                    size: _isMobile ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'অ্যাডমিন রেজিস্ট্রেশন',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'আপনার তথ্য পূরণ করুন',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: _isMobile ? 11 : 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => showForm = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blue,
            fontSize: _isMobile ? 13 : 14,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.blue, size: _isMobile ? 20 : 24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 14 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: !_showPassword,
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: "পাসওয়ার্ড",
          labelStyle: TextStyle(
            color: Colors.blue,
            fontSize: _isMobile ? 13 : 14,
          ),
          hintText: "কমপক্ষে ৬ অক্ষর",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.lock_outline,
              color: Colors.blue, size: _isMobile ? 20 : 24),
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.blue,
              size: _isMobile ? 20 : 24,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 14 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "স্পেশালিস্ট এলাকা",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: showDistrictDialog,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 14 : 20,
              vertical: _isMobile ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDistricts.isEmpty
                        ? "স্পেশালিস্ট সিলেক্ট করুন"
                        : "${selectedDistricts.length} টি স্পেশালিস্ট সিলেক্ট করা হয়েছে",
                    style: TextStyle(
                      color: selectedDistricts.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: _isMobile ? 13 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.blue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedDistricts.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedDistricts.map((d) {
              return Chip(
                label: Text(d.apiValue),
                onDeleted: () {
                  setState(() {
                    selectedDistricts.remove(d);
                  });
                },
                backgroundColor: Colors.blue.withOpacity(0.1),
                deleteIconColor: Colors.blue,
                labelStyle: const TextStyle(color: Colors.blue),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final size = _isMobile ? 100.0 : 120.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "প্রোফাইল ছবি",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: pickImage,
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: pickedImage == null && webImageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt,
                            size: _isMobile ? 32 : 40,
                            color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "ছবি যোগ করুন",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    )
                  : kIsWeb
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            webImageBytes!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            pickedImage!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          FocusScope.of(context).unfocus();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "রেজিস্ট্রেশন হচ্ছে...",
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "দয়া করে অপেক্ষা করুন",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );

          await _submitForm();

          if (mounted) {
            Navigator.pop(context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: _isMobile ? 14 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: Text(
          "রেজিস্ট্রেশন সম্পন্ন করুন",
          style: TextStyle(
            fontSize: _isMobile ? 15 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          "অ্যাডমিন রেজিস্ট্রেশন",
          style: TextStyle(fontSize: _isMobile ? 16 : 20),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: lat_lng.LatLng(23.8103, 90.4125),
                    initialZoom: 13.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.advocatechai.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              );
            },
          ),

          // Gradient Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: _isMobile ? 12 : 16,
            right: _isMobile ? 12 : 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue, size: 20),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(fontSize: _isMobile ? 14 : 16),
                        decoration: const InputDecoration(
                          hintText: "লোকেশন খুঁজুন...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onSubmitted: (value) => searchPlace(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: searchPlace,
                        iconSize: 18,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 20,
            right: _isMobile ? 12 : 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_devicePosition != null) {
                  setState(() {
                    _selectedPosition = _devicePosition;
                    locationTextController.text = _selectedPlaceName ?? '';
                    _updateMarkers();
                  });
                  mapController.move(_devicePosition!, 15.0);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Open Form Button
          if (!showForm)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: _buildOpenFormButton(),
              ),
            ),

          // Animated Form
          _buildAnimatedForm(),
        ],
      ),
    );
  }
}