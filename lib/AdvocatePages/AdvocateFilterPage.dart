import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Utils/AdvocateSpeciality.dart';
import '../AdvocatePages/AdvocateDetailsModel.dart';
import 'AdvocateDetails.dart';
import '../PageTransition.dart';
import '../main.dart';
import '../RegistrationPage/gender.dart';
//import 'AdvocateFilter.dart';

class AdvocateFilterPage extends StatefulWidget {
  const AdvocateFilterPage({super.key});

  @override
  State<AdvocateFilterPage> createState() => _AdvocateFilterPageState();
}

class _AdvocateFilterPageState extends State<AdvocateFilterPage> with SingleTickerProviderStateMixin {
  // Filter Controllers
  AdvocateSpeciality? selectedSpeciality;
  String? selectedLocation;
  Gender? selectedGender;
  String _searchQuery = '';
  
  // Data
  bool loading = true;
  List<AdvocateDetailsModel> list = [];
  List<AdvocateDetailsModel> filteredList = [];
  
  // Animation
  late AnimationController _animationController;
  
  List<String> allLocations = [
    'Bagerhat', 'Bandarban', 'Barguna', 'Barisal', 'Bhola', 'Bogra',
    'Brahmanbaria', 'Chandpur', 'Chapai Nawabganj', 'Chittagong', 'Chuadanga',
    'Comilla', "Cox's Bazar", 'Dhaka', 'Dinajpur', 'Faridpur', 'Feni',
    'Gaibandha', 'Gazipur', 'Gopalganj', 'Habiganj', 'Jamalpur', 'Jessore',
    'Jhalokati', 'Jhenaidah', 'Joypurhat', 'Khagrachari', 'Khulna',
    'Kishoreganj', 'Kurigram', 'Kushtia', 'Lakshmipur', 'Lalmonirhat',
    'Madaripur', 'Magura', 'Manikganj', 'Meherpur', 'Moulvibazar',
    'Munshiganj', 'Mymensingh', 'Naogaon', 'Narail', 'Narayanganj',
    'Narsingdi', 'Natore', 'Netrokona', 'Nilphamari', 'Noakhali', 'Pabna',
    'Panchagarh', 'Patuakhali', 'Pirojpur', 'Rajbari', 'Rajshahi',
    'Rangamati', 'Rangpur', 'Satkhira', 'Shariatpur', 'Sherpur',
    'Sirajganj', 'Sunamganj', 'Sylhet', 'Tangail', 'Thakurgaon'
  ];

  final List<PageTransitionType> _smoothAnimations = AnimatedRoute.getCompanySafeAnimations();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    getAdvocateList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  PageTransitionType _getRandomAnimation() {
    final random = Random().nextInt(_smoothAnimations.length);
    return _smoothAnimations[random];
  }

  void _navigateToMainPage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MyHomePage(title: 'উকিল চাই')),
      (route) => false,
    );
  }

  Future<Uint8List?> fetchProfileImage(String? imageId) async {
    if (imageId == null || imageId.isEmpty) return null;
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse("${BASE_URL.Urls().baseURL}user/download/$imageId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  Gender? _parseGender(String? genderString) {
    if (genderString == null) return null;
    try {
      final upper = genderString.toUpperCase();
      switch (upper) {
        case 'MALE': return Gender.MALE;
        case 'FEMALE': return Gender.FEMALE;
        case 'OTHER': return Gender.OTHER;
        default: return null;
      }
    } catch (e) {
      return null;
    }
  }

  AdvocateDetailsModel _buildAdvocateModel(Map<String, dynamic> advocateDecoded) {
    return AdvocateDetailsModel.defaultConstructor()
      ..id = advocateDecoded["id"]?.toString()
      ..userId = advocateDecoded["userId"]?.toString()
      ..name = advocateDecoded["name"]?.toString()
      ..fullName = advocateDecoded["fullName"]?.toString()
      ..profileImageId = advocateDecoded["profileImageId"]?.toString()
      ..experience = (advocateDecoded["experience"] ?? 0)
      ..licenseKey = advocateDecoded["licenseKey"]?.toString()
      ..advocateSpeciality = advocateDecoded["advocateSpeciality"] != null
          ? List<String>.from(advocateDecoded["advocateSpeciality"].map((e) => e.toString()))
          : []
      ..degrees = advocateDecoded["degrees"] != null
          ? List<String>.from(advocateDecoded["degrees"].map((e) => e.toString()))
          : []
      ..workingExperiences = advocateDecoded["workingExperiences"] != null
          ? List<String>.from(advocateDecoded["workingExperiences"].map((e) => e.toString()))
          : []
      ..email = advocateDecoded["email"]?.toString()
      ..phone = advocateDecoded["phone"]?.toString()
      ..locationName = advocateDecoded["locationName"]?.toString()
      ..lattitude = advocateDecoded["lattitude"] != null 
          ? double.tryParse(advocateDecoded["lattitude"].toString()) 
          : null
      ..longitude = advocateDecoded["longitude"] != null 
          ? double.tryParse(advocateDecoded["longitude"].toString()) 
          : null
      ..contactInfoId = advocateDecoded['contactInfoId']?.toString()
      ..locationId = advocateDecoded['locationId']?.toString()
      ..cvHexKey = advocateDecoded['cvHexKey']?.toString()
      ..district = advocateDecoded['district']?.toString()
      ..userGenderId = advocateDecoded['userGenderId']?.toString()
      ..gender = _parseGender(advocateDecoded['gender']?.toString());
  }

  // ============ API METHODS ============
  Future<void> getAdvocateList() async {
    setState(() { loading = true; list.clear(); filteredList.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/all"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode != 200) throw Exception("Failed to load advocates");
      final List responseData = jsonDecode(response.body);
      List<AdvocateDetailsModel> models = [];
      for (final item in responseData) {
        models.add(_buildAdvocateModel(item as Map<String, dynamic>));
      }
      setState(() {
        list = models;
        _applyFilters();
        loading = false;
        _animationController.forward();
      });
    } catch (e) {
      debugPrint("Error loading advocates: $e");
      setState(() { loading = false; list.clear(); filteredList.clear(); });
    }
  }

  Future<void> fetchBySpeciality(AdvocateSpeciality speciality) async {
    setState(() { loading = true; list.clear(); filteredList.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/search/speciality/${speciality.name}"),
        headers: {"Authorization": "Bearer $token", "content-type": "application/json"},
      );
      if (response.statusCode == 200) {
        final List responseData = jsonDecode(response.body);
        List<AdvocateDetailsModel> models = [];
        for (final item in responseData) {
          models.add(_buildAdvocateModel(item as Map<String, dynamic>));
        }
        setState(() {
          list = models;
          _applyFilters();
          loading = false;
          _animationController.forward();
        });
      } else {
        setState(() { loading = false; list.clear(); filteredList.clear(); });
      }
    } catch (e) {
      debugPrint("Error fetching by speciality: $e");
      setState(() { loading = false; list.clear(); filteredList.clear(); });
    }
  }

  Future<void> fetchByLocation(String location) async {
    setState(() { loading = true; list.clear(); filteredList.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/find/district/$location"),
        headers: {"Authorization": "Bearer $token", "content-type": "application/json"},
      );
      if (response.statusCode == 200) {
        final List responseData = jsonDecode(response.body);
        List<AdvocateDetailsModel> models = [];
        for (final item in responseData) {
          models.add(_buildAdvocateModel(item as Map<String, dynamic>));
        }
        setState(() {
          list = models;
          _applyFilters();
          loading = false;
          _animationController.forward();
        });
      } else {
        setState(() { loading = false; list.clear(); filteredList.clear(); });
      }
    } catch (e) {
      debugPrint("Location filter error: $e");
      setState(() { loading = false; list.clear(); filteredList.clear(); });
    }
  }

  Future<void> fetchByGender(Gender gender) async {
    setState(() { loading = true; list.clear(); filteredList.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/findByGender/${gender.displayName.toUpperCase()}"),
        headers: {"Authorization": "Bearer $token", "content-type": "application/json"},
      );
      if (response.statusCode == 200) {
        final List responseData = jsonDecode(response.body);
        List<AdvocateDetailsModel> models = [];
        for (final item in responseData) {
          models.add(_buildAdvocateModel(item as Map<String, dynamic>));
        }
        setState(() {
          list = models;
          filteredList = models;
          selectedGender = gender;
          loading = false;
          _animationController.forward();
        });
      } else if (response.statusCode == 404) {
        setState(() { list = []; filteredList = []; loading = false; });
      } else {
        throw Exception("Failed to fetch advocates by gender");
      }
    } catch (e) {
      debugPrint("Gender filter error: $e");
      setState(() { loading = false; list.clear(); filteredList.clear(); });
    }
  }

  // ============ FILTER METHODS ============
  void _applyFilters() {
    setState(() {
      filteredList = List.from(list);
      _applyLocalFilters();
    });
  }

  void _applyLocalFilters() {
    if (selectedLocation != null && selectedLocation!.isNotEmpty) {
      filteredList = filteredList
          .where((adv) => adv.district == selectedLocation || adv.locationName == selectedLocation)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredList = filteredList.where((adv) {
        final name = (adv.fullName ?? adv.name ?? '').toLowerCase();
        final speciality = adv.advocateSpeciality.join(' ').toLowerCase();
        final location = (adv.locationName ?? '').toLowerCase();
        return name.contains(query) || speciality.contains(query) || location.contains(query);
      }).toList();
    }
  }

  void _clearFilters() {
    setState(() {
      selectedSpeciality = null;
      selectedLocation = null;
      selectedGender = null;
      _searchQuery = '';
    });
    getAdvocateList();
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (selectedSpeciality != null) count++;
    if (selectedLocation != null) count++;
    if (selectedGender != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  Color _getGenderColor(Gender gender) {
    switch (gender) {
      case Gender.MALE: return Colors.blue;
      case Gender.FEMALE: return Colors.pink;
      case Gender.OTHER: return Colors.purple;
    }
  }

  IconData _getGenderIcon(Gender gender) {
    switch (gender) {
      case Gender.MALE: return Icons.male;
      case Gender.FEMALE: return Icons.female;
      case Gender.OTHER: return Icons.transgender;
    }
  }

  String _getGenderDisplayName(Gender gender) {
    switch (gender) {
      case Gender.MALE: return 'Male';
      case Gender.FEMALE: return 'Female';
      case Gender.OTHER: return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToMainPage();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Search Bar
              _buildSearchBar(),
              
              // Stats and Filter Chips
              _buildStatsAndFilters(),
              
              const SizedBox(height: 8),
              
              // Content
              Expanded(
                child: loading
                    ? _buildLoadingState()
                    : filteredList.isEmpty && list.isEmpty
                        ? _buildEmptyState()
                        : _buildAdvocateList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ UI COMPONENTS ============
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.gavel,
              color: Colors.purple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Your Advocate',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '${filteredList.isNotEmpty ? filteredList.length : list.length} advocates available',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _navigateToMainPage,
            icon: Icon(Icons.close, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _applyFilters();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search by name, speciality, or location...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatChip(
                icon: Icons.people,
                label: '${filteredList.isNotEmpty ? filteredList.length : list.length}',
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                icon: Icons.location_city,
                label: '${allLocations.length} Locations',
                color: Colors.blue,
              ),
              const Spacer(),
              if (_getActiveFilterCount() > 0)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_all, size: 14, color: Colors.red[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Clear All',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Speciality',
                  value: selectedSpeciality?.label ?? 'All',
                  onTap: _showSpecialityPicker,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Location',
                  value: selectedLocation ?? 'All',
                  onTap: _showLocationPicker,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Gender',
                  value: selectedGender != null 
                      ? _getGenderDisplayName(selectedGender!) 
                      : 'All',
                  onTap: _showGenderPicker,
                  icon: selectedGender != null 
                      ? Icon(_getGenderIcon(selectedGender!), size: 14, color: _getGenderColor(selectedGender!))
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? icon,
  }) {
    final isActive = value != 'All';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.purple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.purple : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
            if (icon != null) icon,
            if (icon != null) const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? Colors.white : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading advocates...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No advocates found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvocateList() {
    final displayList = filteredList.isNotEmpty ? filteredList : list;
    return RefreshIndicator(
      onRefresh: () async {
        if (selectedGender != null) {
          await fetchByGender(selectedGender!);
        } else {
          await getAdvocateList();
        }
      },
      color: Colors.purple,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          return FadeInUpAnimation(
            delay: index * 50,
            child: _buildAdvocateCard(displayList[index], index),
          );
        },
      ),
    );
  }

  Widget _buildAdvocateCard(AdvocateDetailsModel adv, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await NavigationHelper.push(
              context,
              AdvocateDetails(advocateDetailsModel: adv),
              transitionType: _getRandomAnimation(),
              duration: const Duration(milliseconds: 400),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Profile Image
                _buildProfileImage(adv.profileImageId),
                
                const SizedBox(width: 14),
                
                // Advocate Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              adv.fullName ?? adv.name ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (adv.gender != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getGenderColor(adv.gender!).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getGenderIcon(adv.gender!),
                                    size: 10,
                                    color: _getGenderColor(adv.gender!),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _getGenderDisplayName(adv.gender!),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: _getGenderColor(adv.gender!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Experience and Speciality
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildInfoChip(
                            icon: Icons.work_outline,
                            label: '${adv.experience ?? 0}yrs',
                          ),
                          if (adv.advocateSpeciality.isNotEmpty)
                            _buildInfoChip(
                              icon: Icons.star_outline,
                              label: adv.advocateSpeciality.length > 2
                                  ? '${adv.advocateSpeciality.take(2).join(', ')}...'
                                  : adv.advocateSpeciality.join(', '),
                            ),
                        ],
                      ),
                      
                      if (adv.locationName != null && adv.locationName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  adv.locationName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Arrow
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? imageId) {
    return FutureBuilder<Uint8List?>(
      future: fetchProfileImage(imageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purple[400]!, Colors.blue[400]!],
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purple[400]!, Colors.blue[400]!],
              ),
            ),
            child: Icon(Icons.person, size: 28, color: Colors.white),
          );
        }

        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(snapshot.data!),
          backgroundColor: Colors.transparent,
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ============ PICKER METHODS ============
  
  void _showSpecialityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Speciality',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildPickerItem(
                      title: 'All Specialities',
                      isSelected: selectedSpeciality == null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => selectedSpeciality = null);
                        getAdvocateList();
                      },
                    ),
                    ...AdvocateSpeciality.values.map(
                      (s) => _buildPickerItem(
                        title: s.label,
                        icon: s.icon,
                        isSelected: selectedSpeciality == s,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => selectedSpeciality = s);
                          fetchBySpeciality(s);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Location',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildPickerItem(
                      title: 'All Locations',
                      isSelected: selectedLocation == null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => selectedLocation = null);
                        getAdvocateList();
                      },
                    ),
                    ...allLocations.map(
                      (loc) => _buildPickerItem(
                        title: loc,
                        isSelected: selectedLocation == loc,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => selectedLocation = loc);
                          fetchByLocation(loc);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Gender',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildPickerItem(
                      title: 'All Genders',
                      isSelected: selectedGender == null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => selectedGender = null);
                        getAdvocateList();
                      },
                    ),
                    ...Gender.values.map(
                      (g) => _buildPickerItem(
                        title: _getGenderDisplayName(g),
                        icon: _getGenderIcon(g),
                        iconColor: _getGenderColor(g),
                        isSelected: selectedGender == g,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => selectedGender = g);
                          fetchByGender(g);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerItem({
    required String title,
    IconData? icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: iconColor ?? Colors.purple)
          : null,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? Colors.purple : Colors.grey[800],
        ),
      ),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 16, color: Colors.white),
            )
          : null,
      onTap: onTap,
    );
  }
}

// ============ ANIMATION WIDGET ============
class FadeInUpAnimation extends StatefulWidget {
  final Widget child;
  final int delay;

  const FadeInUpAnimation({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<FadeInUpAnimation> createState() => _FadeInUpAnimationState();
}

class _FadeInUpAnimationState extends State<FadeInUpAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}