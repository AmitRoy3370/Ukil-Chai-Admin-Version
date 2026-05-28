import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advocatechaiadmin/Utils/BaseURL.dart' as baseURL;
import 'package:advocatechaiadmin/Auth/AuthService.dart';
import 'package:http_parser/http_parser.dart';
import 'package:advocatechaiadmin/Utils/AdvocateSpeciality.dart';

class UpdateProfile extends StatefulWidget {
  const UpdateProfile({super.key});

  @override
  State<UpdateProfile> createState() => _UpdateProfileState();
}

class _UpdateProfileState extends State<UpdateProfile> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController oldNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationTextController = TextEditingController();

  bool _showPassword = false, _showOldPassword = false;

  lat_lng.LatLng? _devicePosition;
  lat_lng.LatLng? _selectedPosition;
  String? _selectedPlaceName;
  List<Marker> _markers = [];
  bool showForm = false;
  bool locationPresent = false;
  File? pickedImage;
  Uint8List? webImageBytes;
  double latitude = 0.0;
  double longitude = 0.0;

  bool loading = true;
  bool isUpdating = false;

  final MapController mapController = MapController();

  Stream<Position>? _positionStream;

  // Focus nodes
  final FocusNode _oldNameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _oldPasswordFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  get userIdValue => null;

  List<String> admins = [];
  List<String> advocates = [];

  late List<String?> selectedDistricts = [];

  final List<String> bangladeshDistricts = AdvocateSpeciality.values
      .map((e) => e.name)
      .toList();

  Future<File?> convertBytesToFile(
      Uint8List bytes, {
        required String extension,
      }) async {
    if (kIsWeb) {
      print('Conversion to File not supported on web. Use bytes directly.');
      return null;
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/profile.$extension';
      final file = File(tempPath);
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  Future<void> loadPreviousData() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      print("No token find at here...");
      return;
    }

    final userId = await AuthService.getUserId();

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}user/search?userId=$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        oldNameController.text = data["name"] ?? "";
        nameController.text = data["name"] ?? "";
      });

      final profileImageId = data["profileImageId"];
      if (profileImageId != null) {
        final profileImageURL = "${baseURL.Urls().baseURL}user/download/$profileImageId";
        final profileImageResponse = await http.get(
          Uri.parse(profileImageURL),
          headers: {
            "Accept": "image/*,application/octet-stream",
            "Authorization": "Bearer $token",
          },
        );
        if (profileImageResponse.statusCode == 200 && profileImageResponse.bodyBytes.isNotEmpty) {
          final bytes = profileImageResponse.bodyBytes;
          bool isJpeg = bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
          bool isPng = bytes.length > 4 &&
              bytes[0] == 0x89 && bytes[1] == 0x50 &&
              bytes[2] == 0x4E && bytes[3] == 0x47;
          bool isLikelyImage = isJpeg || isPng;

          if (isLikelyImage && mounted) {
            setState(() {
              webImageBytes = bytes;
            });
            try {
              final extension = isJpeg ? 'jpg' : 'png';
              final file = await convertBytesToFile(bytes, extension: extension);
              if (mounted) {
                setState(() {
                  pickedImage = file;
                  loading = false;
                });
              }
            } catch (e) {
              print(e.toString());
              if (mounted) setState(() => loading = false);
            }
          } else {
            if (mounted) setState(() => loading = false);
          }
        }
      }

      final locationURL = "${baseURL.Urls().baseURL}userLocation/findByUserId/$userId";
      final locationResponse = await http.get(
        Uri.parse(locationURL),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (locationResponse.statusCode == 200) {
        final locationResponseData = jsonDecode(locationResponse.body);
        if (mounted) {
          setState(() {
            locationPresent = true;
            locationTextController.text = locationResponseData["locationName"] ?? "";
            latitude = locationResponseData["lattitude"] ?? 0.0;
            longitude = locationResponseData["longitude"] ?? 0.0;
            _selectedPosition = lat_lng.LatLng(latitude, longitude);
          });
        }
      }

      final userContactInfoURL = "${baseURL.Urls().baseURL}user/contact-info/user?userId=$userId";
      final userContactInfoResponse = await http.get(
        Uri.parse(userContactInfoURL),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (userContactInfoResponse.statusCode == 200) {
        final userContactInfoResponseData = jsonDecode(userContactInfoResponse.body);
        if (mounted) {
          setState(() {
            emailController.text = userContactInfoResponseData["email"] ?? "";
            phoneController.text = userContactInfoResponseData["phone"] ?? "";
          });
        }
      }

      final centerAdminResponse = await http.get(
        Uri.parse("${baseURL.Urls().baseURL}admin/by-user/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (centerAdminResponse.statusCode == 200) {
        final centerAdminResponseData = jsonDecode(centerAdminResponse.body);
        if (mounted) {
          setState(() {
            selectedDistricts = List<String?>.from(centerAdminResponseData["advocateSpeciality"] ?? []);
          });
        }
      }
    } else {
      print("Failed to load previous data: ${response.statusCode}");
    }
  }

  void showDistrictDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Select Speciality",
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: bangladeshDistricts.map((district) {
                    return CheckboxListTile(
                      title: Text(district),
                      value: selectedDistricts.contains(district),
                      onChanged: (value) {
                        dialogSetState(() {
                          if (value == true) {
                            if (!selectedDistricts.contains(district)) {
                              selectedDistricts.add(district);
                            }
                          } else {
                            selectedDistricts.remove(district);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done", style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDistrict(String district) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove District"),
        content: Text("Are you sure you want to remove $district?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        selectedDistricts.remove(district);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$district removed"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPreviousData();
      _startLocationUpdates();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    oldNameController.dispose();
    passwordController.dispose();
    oldPasswordController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationTextController.dispose();
    _oldNameFocus.dispose();
    _nameFocus.dispose();
    _oldPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable location service")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission denied forever")),
      );
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
      locationPresent ? latitude : position.latitude,
      locationPresent ? longitude : position.longitude,
    );
    String placeName = await getAddressFromLatLng(
      locationPresent ? latitude : position.latitude,
      locationPresent ? longitude : position.longitude,
    );

    setState(() {
      _devicePosition = newPos;
      if (_selectedPosition == null) {
        _selectedPosition = newPos;
        _selectedPlaceName = placeName;
        latitude = position.latitude;
        longitude = position.longitude;
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
        setState(() => locationPresent = false);
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lng = double.parse(data[0]['lon']);
          setState(() {
            latitude = lat;
            longitude = lng;
          });
          pos = lat_lng.LatLng(lat, lng);
          String name = data[0]['display_name'];
          _selectedPosition = pos;
          _selectedPlaceName = name;
          locationTextController.text = _selectedPlaceName!;
          _updateMarkers();
          mapController.move(pos, 15.0);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Search error: $e');
    }

    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found")));
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
              title: const Text('গ্যালারি থেকে নির্বাচন করুন'),
              onTap: () async {
                Navigator.pop(context);
                XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (file != null) {
                  if (kIsWeb) {
                    webImageBytes = await file.readAsBytes();
                  } else {
                    pickedImage = File(file.path);
                  }
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('ক্যামেরা দিয়ে তুলুন'),
              onTap: () async {
                Navigator.pop(context);
                XFile? file = await ImagePicker().pickImage(source: ImageSource.camera);
                if (file != null) {
                  if (kIsWeb) {
                    webImageBytes = await file.readAsBytes();
                  } else {
                    pickedImage = File(file.path);
                  }
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;
    setState(() => isUpdating = true);

    try {
      final logInUri = Uri.parse("${baseURL.Urls().baseURL}auth/login");
      final logInResponse = await http.post(
        logInUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": oldNameController.text.trim(),
          "password": oldPasswordController.text.trim(),
        }),
      );

      if (logInResponse.statusCode != 200) {
        _showSnackBar("পুরনো পাসওয়ার্ড সঠিক নয়", Colors.red);
        setState(() => isUpdating = false);
        return;
      }

      final decoded = jsonDecode(logInResponse.body);
      String? token = decoded["token"];
      String? userId = decoded["userId"];

      final uri = Uri.parse("${baseURL.Urls().baseURL}user/update/$userId");
      var request = http.MultipartRequest("PUT", uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields["name"] = nameController.text.trim();
      request.fields["password"] = passwordController.text.trim();

      final imageFindingUri = Uri.parse("${baseURL.Urls().baseURL}user/search?userId=$userId");
      final imageFindingResponse = await http.get(
        imageFindingUri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final imageFindingResponseData = jsonDecode(imageFindingResponse.body);
      String? profileImageId = imageFindingResponseData["profileImageId"];
      if (profileImageId != null && profileImageId.isNotEmpty) {
        request.fields["profileImageId"] = profileImageId;
      }

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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", token!);
        await prefs.setString("userId", userId!);
        AuthService.saveToken(token);
        AuthService.saveUserId(userId);

        await _updateContactInfo(userId!, token);
        await _updateLocationInfo(userId!, token);
        await _updateCenterAdminInfo(userId!, token);

        _showSnackBar("প্রোফাইল আপডেট সফল হয়েছে! 🎉", Colors.green);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => showForm = false);
          }
        });
      } else {
        _showSnackBar("আপডেট ব্যর্থ হয়েছে: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("একটি ত্রুটি ঘটেছে: $e", Colors.red);
    } finally {
      setState(() => isUpdating = false);
    }
  }

  bool _validateForm() {
    if (nameController.text.isEmpty) {
      _showSnackBar("নতুন নাম লিখুন", Colors.orange);
      return false;
    }
    if (oldPasswordController.text.isEmpty) {
      _showSnackBar("পুরনো পাসওয়ার্ড লিখুন", Colors.orange);
      return false;
    }
    if (passwordController.text.isEmpty) {
      _showSnackBar("নতুন পাসওয়ার্ড লিখুন", Colors.orange);
      return false;
    }
    if (locationTextController.text.isEmpty) {
      _showSnackBar("লোকেশন সিলেক্ট করুন", Colors.orange);
      return false;
    }
    return true;
  }

  Future<void> _updateContactInfo(String userId, String token) async {
    final contactInfoUri = Uri.parse("${baseURL.Urls().baseURL}user/contact-info/user?userId=$userId");
    final response = await http.get(
      contactInfoUri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String contactInfoId = data["id"];
      final updateUri = Uri.parse("${baseURL.Urls().baseURL}user/contact-info/update?userId=$userId&contactInfoId=$contactInfoId");
      await http.put(
        updateUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "email": emailController.text.isNotEmpty ? emailController.text.trim() : null,
          "phone": phoneController.text.isNotEmpty ? phoneController.text.trim() : null,
        }),
      );
    } else {
      final addUri = Uri.parse("${baseURL.Urls().baseURL}user/contact-info/add?userId=$userId");
      await http.post(
        addUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "email": emailController.text.isNotEmpty ? emailController.text.trim() : null,
          "phone": phoneController.text.isNotEmpty ? phoneController.text.trim() : null,
        }),
      );
    }
  }

  Future<void> _updateLocationInfo(String userId, String token) async {
    final locationUri = Uri.parse("${baseURL.Urls().baseURL}userLocation/findByUserId/$userId");
    final response = await http.get(
      locationUri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String locationInfoId = data["id"];
      final updateUri = Uri.parse("${baseURL.Urls().baseURL}userLocation/update/$locationInfoId?userId=$userId");
      await http.put(
        updateUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "locationName": locationTextController.text.trim(),
          "lattitude": latitude,
          "longitude": longitude,
        }),
      );
    } else {
      final addUri = Uri.parse("${baseURL.Urls().baseURL}userLocation/add");
      await http.post(
        addUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "locationName": locationTextController.text.trim(),
          "lattitude": latitude,
          "longitude": longitude,
        }),
      );
    }
  }

  Future<void> _updateCenterAdminInfo(String userId, String token) async {
    final centerAdminResponse = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}admin/by-user/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (centerAdminResponse.statusCode == 200) {
      final centerAdminResponseData = jsonDecode(centerAdminResponse.body);
      final centerAdminId = centerAdminResponseData["id"];
      await http.put(
        Uri.parse("${baseURL.Urls().baseURL}admin/update/$centerAdminId/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "userId": userId,
          "advocateSpeciality": selectedDistricts,
        }),
      );
    }
  }

  void _showSnackBar(String message, Color color) {
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

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
            const SizedBox(height: 16),
            Text("আপডেট হচ্ছে...", style: TextStyle(fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 8),
            Text("দয়া করে অপেক্ষা করুন", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildOpenFormButton() {
    return GestureDetector(
      onTap: () => setState(() => showForm = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'অ্যাডমিন প্রোফাইল আপডেট',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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
      height: MediaQuery.of(context).size.height * 0.85,
      child: IgnorePointer(
        ignoring: !showForm,
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: showForm ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 100),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5)),
              ],
            ),
            child: Column(
              children: [
                _buildDragHandle(),
                _buildFormHeader(),
                Expanded(child: _buildFormContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 10) setState(() => showForm = false);
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
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('অ্যাডমিন প্রোফাইল আপডেট', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('আপনার তথ্য হালনাগাদ করুন', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => showForm = false),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 24),
          _buildTextField(
            controller: oldNameController,
            label: "পুরনো নাম",
            icon: Icons.person_outline,
            readOnly: true,
            focusNode: _oldNameFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: nameController,
            label: "নতুন নাম",
            icon: Icons.person,
            hint: "আপনার নতুন নাম লিখুন",
            focusNode: _nameFocus,
            nextFocus: _oldPasswordFocus,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: oldPasswordController,
            label: "পুরনো পাসওয়ার্ড",
            isVisible: _showOldPassword,
            onToggle: () => setState(() => _showOldPassword = !_showOldPassword),
            focusNode: _oldPasswordFocus,
            nextFocus: _newPasswordFocus,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: passwordController,
            label: "নতুন পাসওয়ার্ড",
            isVisible: _showPassword,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            focusNode: _newPasswordFocus,
            nextFocus: _emailFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: emailController,
            label: "ইমেইল",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            nextFocus: _phoneFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: phoneController,
            label: "মোবাইল নম্বর",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            focusNode: _phoneFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: locationTextController,
            label: "লোকেশন",
            icon: Icons.location_on_outlined,
            readOnly: true,
            onTap: () => _showSnackBar("মানচিত্রে ট্যাপ করে লোকেশন সিলেক্ট করুন", Colors.blue),
          ),
          const SizedBox(height: 20),
          _buildSpecialistSection(),
          const SizedBox(height: 30),
          _buildSubmitButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: GestureDetector(
        onTap: pickImage,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
            boxShadow: [
              BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (pickedImage != null && !kIsWeb)
                  Image.file(pickedImage!, fit: BoxFit.cover)
                else if (webImageBytes != null && kIsWeb)
                  Image.memory(webImageBytes!, fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white,
                    child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.blue),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(55),
                        bottomRight: Radius.circular(55),
                      ),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    FocusNode? focusNode,
    FocusNode? nextFocus,
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
        focusNode: focusNode,
        onTap: onTap,
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onEditingComplete: () {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.blue),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        focusNode: focusNode,
        textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onEditingComplete: () {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.blue),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.blue),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: showDistrictDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.gavel, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDistricts.isEmpty
                        ? "স্পেশালিস্ট সিলেক্ট করুন"
                        : "${selectedDistricts.length} টি স্পেশালিস্ট সিলেক্ট করা হয়েছে",
                    style: TextStyle(
                      color: selectedDistricts.isEmpty ? Colors.grey[600] : Colors.black87,
                    ),
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
            children: selectedDistricts.map((district) {
              return Chip(
                label: Text(district!),
                onDeleted: () => _confirmDeleteDistrict(district!),
                backgroundColor: Colors.blue.withOpacity(0.1),
                deleteIconColor: Colors.blue,
                labelStyle: const TextStyle(color: Colors.blue),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isUpdating ? null : () async {
          FocusScope.of(context).unfocus();
          _showLoadingDialog();
          await _submitForm();
          if (mounted) Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
        ),
        child: isUpdating
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('আপডেট করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("অ্যাডমিন প্রোফাইল আপডেট"),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
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
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.6)],
                ),
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: "লোকেশন খুঁজুন...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onSubmitted: (value) => searchPlace(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(30)),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: searchPlace,
                        iconSize: 20,
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
            right: 16,
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
              child: Center(child: _buildOpenFormButton()),
            ),

          // Animated Form
          _buildAnimatedForm(),
        ],
      ),
    );
  }
}