// HomePage.dart - Updated Full Version

import 'package:advocatechaiadmin/HomePage/AdvocateList.dart';
import 'package:advocatechaiadmin/HomePage/QuickConnect.dart';
import 'package:advocatechaiadmin/PostRelatedPages/post_feed_page_home_page.dart';
import 'package:advocatechaiadmin/PostRelatedPages/post_feed_page.dart';
import 'package:advocatechaiadmin/AdvocatePages/AdvocateFilterPage.dart';
import 'package:advocatechaiadmin/AdvocatePages/AdvocateHomePage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'LifeCycles/PresenceSocketService.dart';
import 'package:http/http.dart' as http;
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Farayez/farayez_calculator.dart';
import '../HomePage/corporate_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  Timer? _heartbeatTimer;
  bool _isWelcomeBannerVisible = true;

  // ========== লোকেশন লিস্ট ==========
  final List<String> allLocations = [
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

  @override
  void initState() {
    super.initState();
    heartbit();

  }

  Future<void> heartbit() async {

      final userId = await AuthService.getUserId();

      if(userId != null) {

         _startHeartbeat(userId!);

      }

  }

  void _startHeartbeat(String userId) {
    _heartbeatTimer = Timer.periodic(
    const Duration(seconds: 20),
    (timer) async {
       try {
      // ✅ Direct heartbeat by userId
      final url = Uri.parse("${BASE_URL.Urls().baseURL}user-active/heartbeat/$userId");
      
      final token = await AuthService.getToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        //_lastHeartbeatTime = DateTime.now();
        //print("💓 Heartbeat sent at ${_lastHeartbeatTime?.toLocal()}");
      } else {
        print("❌ Heartbeat failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Heartbeat error: $e");
    }
    },
  );
}


  @override
  Widget build(BuildContext context) {

    final screenWidth = MediaQuery.of(context).size.width;

    final isDesktop = screenWidth > 800;

    final isTablet = screenWidth > 600 && screenWidth <= 800;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade50,
            Colors.white,
            Colors.green.shade50,
          ],
        ),
      ),

      child: RefreshIndicator(

        onRefresh: () async {

          setState(() {

          });

        },

        child: SingleChildScrollView(

          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),

          child: Padding(

            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
              vertical: 20,
            ),

            child: Column(

              children: [

                _buildWelcomeBanner(
                  context,
                  isDesktop,
                  isTablet,
                ),

                const SizedBox(height: 24),

                QuickConnect(
                  key: UniqueKey(),
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(
                  "Recent Legal Updates",
                  Icons.newspaper,
                ),

                const SizedBox(height: 16),

                PostFeedPageHomePage(
                  key: UniqueKey(),
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(
                  "Featured Advocates",
                  Icons.star,
                ),

                const SizedBox(height: 16),

                AdvocateList(
                  key: UniqueKey(),
                ),

                const SizedBox(height: 20),


                  const SizedBox(height: 20),
                  const CorporateBanner(),
                  const SizedBox(height: 20),
                  const FarayezCalculator(),
                  const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }

// ========== WELCOME BANNER ==========
Widget _buildWelcomeBanner(
    BuildContext context, bool isDesktop, bool isTablet) {
  if (!_isWelcomeBannerVisible) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isWelcomeBannerVisible = true;
              });
            },
            icon: const Icon(
              Icons.expand_more,
              color: Colors.green,
              size: 20,
            ),
            label: Text(
              "Show Welcome Message",
              style: GoogleFonts.inter(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.green.shade200,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Logo size adapts to screen
  final double logoSize = isDesktop ? 64 : (isTablet ? 56 : 48);
  final double logoRingPadding = isDesktop ? 4 : 3;
  final double logoInnerPadding = isDesktop ? 6 : 5;

  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: isDesktop ? 40 : 24,
      vertical: isDesktop ? 32 : 24,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ═══════════════════════════════════════════════
                // ✅ Attractive Round Logo
                // ═══════════════════════════════════════════════
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Soft glow behind the logo
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                    // Outer white ring (contrast against green background)
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: logoRingPadding,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF1F8E9),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(logoInnerPadding),
                    child: ClipOval(
                      child: Container(
                        color: Colors.white,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          // Fallback if asset missing
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.gavel_rounded,
                            color: Color(0xFF1B5E20),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Text(
                    "Welcome to উকিল",
                    style: GoogleFonts.poppins(
                      fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Your trusted legal partner. Connect with expert advocates, get legal advice, and manage your cases efficiently.",
              style: GoogleFonts.inter(
                fontSize: isDesktop ? 16 : 14,
                color: Colors.white.withOpacity(0.95),
                height: 1.5,
              ),
            ),
          ],
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            onPressed: () {
              setState(() {
                _isWelcomeBannerVisible = false;
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildActionButton(
      String text,
      IconData icon,
      Color textColor,
      Color bgColor,
      ) {

    return ElevatedButton.icon(

      onPressed: () {},

      icon: Icon(icon, size: 18),

      label: Text(text),

      style: ElevatedButton.styleFrom(

        foregroundColor: textColor,

        backgroundColor: bgColor,

        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        elevation: 0,
      ),
    );
  }

  Widget _buildSectionHeader(
      String title,
      IconData icon,
      ) {

    return Row(

      children: [

        Container(

          padding: const EdgeInsets.all(8),

          decoration: BoxDecoration(

            gradient: LinearGradient(
              colors: [
                Colors.green.shade400,
                Colors.green.shade600,
              ],
            ),

            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(

          child: Text(

            title,

            style: GoogleFonts.poppins(

              fontSize: 20,

              fontWeight: FontWeight.bold,

              color: Colors.green.shade800,
            ),
          ),
        ),

        TextButton(

          onPressed: () {

              if(title == 'Featured Advocates') {

                   Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdvocateHomePage()),
                );

              } else if(title == 'Recent Legal Updates') {

                   Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PostFeedPage()),
                );

              }

          },

          child: Text(

            "See All",

            style: GoogleFonts.inter(

              color: Colors.green.shade600,

              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}