// lib/ProfilePage/ProfileMenuPage.dart
//
// Admin Profile Menu — full port of the user panel's ProfileHubPage design,
// adapted for the admin panel. All menu rows now open the SAME pages as the
// user panel, and the Director registration + director profile flow is wired
// into the Identity & Verification section.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASEURL;
import 'ProfileImageWidget.dart';
import 'SeeMyProfile.dart';
import 'UpdateProfile.dart';

// ── User-panel pages (copied into admin project) ────────────────────────────
import '../CaseRelatedPages/CaseHomePage.dart';
import '../AboutUkilScreen.dart';
import '../ChatRelatedPages/FreeConsultantPage.dart';
import '../QuestionPages/MyQuestionsPage.dart';
import '../AdvocatePages/BookmarkService.dart';
import '../AdvocatePages/SavedAdvocatesPage.dart';

// ── Director flow ───────────────────────────────────────────────────────────
import '../DirectorsPages/director_service.dart';
import '../DirectorsPages/director_response.dart';
import '../DirectorsPages/DirectorRegistrationScreen.dart';
import '../DirectorsPages/director_profile_page.dart';

// ─── Design tokens (identical to user panel) ────────────────────────────────
class _C {
  static const forest      = Color(0xFF1A3C2B);
  static const mid         = Color(0xFF2D6A4F);
  static const sage        = Color(0xFF52B788);
  static const frost       = Color(0xFFF0F7F3);
  static const ivory       = Color(0xFFFAFAF8);
  static const ink         = Color(0xFF111B17);
  static const slate       = Color(0xFF4B5563);
  static const mist        = Color(0xFF9CA3AF);
  static const line        = Color(0xFFE4EBE7);
  static const danger      = Color(0xFFDC2626);
  static const dangerPale  = Color(0xFFFEF2F2);
  static const warn        = Color(0xFF92400E);
  static const warnPale    = Color(0xFFFFFBEB);
  static const success     = Color(0xFF065F46);
  static const successPale = Color(0xFFECFDF5);
}

// ─── Safe helpers (dart2js-safe) ─────────────────────────────────────────────
//
// CRITICAL for Flutter Web (dart2js):
// `v == null` does NOT always catch JavaScript `undefined`.
// `v is String` can THROW when `v` is a raw JS value without a Dart wrapper.
// Every type check must be inside a try/catch.
String _s(dynamic v) {
  try {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num) return v.toString();
    if (v is bool) return v.toString();
    if (v is Map || v is List) return jsonEncode(v);
    final s = v.toString();
    return s == 'null' ? '' : s;
  } catch (_) {
    return '';
  }
}

double? _toDouble(dynamic v) {
  try {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
  } catch (_) {}
  return null;
}

Map<String, dynamic> _asMap(dynamic v) {
  try {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  return const {};
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _AdminUser {
  final String id;
  final String name;
  final String fullName;
  final String password;
  final String profileImageId;
  final String email;
  final String phone;
  final double? lattitude;
  final double? longitude;
  final String locationName;

  _AdminUser({
    required this.id,
    required this.name,
    required this.fullName,
    required this.password,
    required this.profileImageId,
    required this.email,
    required this.phone,
    this.lattitude,
    this.longitude,
    this.locationName = '',
  });

  factory _AdminUser.fromApis({
    Map<String, dynamic>? user,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? location,
  }) {
    final u = _asMap(user);
    final c = _asMap(contact);
    final l = _asMap(location);

    return _AdminUser(
      id: _s(u['id']),
      name: _s(u['name']).trim(),
      fullName: _s(u['fullName']).trim(),
      password: _s(u['password']),
      profileImageId: _s(u['profileImageId']),
      email: _s(c['email']).trim(),
      phone: _s(c['phone']).trim(),
      lattitude: _toDouble(l['lattitude']),
      longitude: _toDouble(l['longitude']),
      locationName: _s(l['locationName']).trim(),
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (name.isNotEmpty) return name;
    return 'Admin';
  }

  String get initials {
    final src = displayName.trim();
    if (src.isEmpty) return '?';
    final parts = src.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

// A "case" placeholder so we can reuse the Case Detail design.
class _CaseItem {
  final String id, title, advocate, type, status, hearing, filed, paid, icon;
  final int progress, total;
  const _CaseItem({
    required this.id,
    required this.title,
    required this.advocate,
    required this.type,
    required this.status,
    required this.hearing,
    required this.filed,
    required this.paid,
    required this.progress,
    required this.total,
    required this.icon,
  });
}

// ─── Reusable widgets (identical look to user panel) ────────────────────────

class _SealAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color ring;
  const _SealAvatar({
    required this.initials,
    this.size = 44,
    this.ring = _C.mid,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 8,
            height: size + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring.withOpacity(0.6), width: 1.5),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ring.withOpacity(0.15), ring.withOpacity(0.30)],
              ),
              border: Border.all(color: ring, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: size * 0.33,
                color: ring,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case "In Progress":
      case "Answered":
      case "Paid":
      case "Approved":
      case "Verified":
        bg = _C.successPale;
        fg = _C.success;
        break;
      case "Pending":
      case "Unanswered":
      case "Under Review":
        bg = _C.warnPale;
        fg = _C.warn;
        break;
      case "Closed":
      case "Rejected":
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        break;
      default:
        bg = _C.frost;
        fg = _C.mid;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int progress;
  final int total;
  const _ProgressBar({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
          color: _C.line, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        widthFactor: total == 0 ? 0 : (progress / total).clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.forest, _C.sage]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? action;
  const _BackHeader({
    required this.title,
    required this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.arrow_back, size: 22, color: _C.forest),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _C.ink)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? icon;
  const _InfoRow({required this.label, this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final raw = (value ?? '').trim();
    final displayValue = raw.isEmpty ? '—' : raw;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: _C.mist)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String icon;
  final String label;
  final String? sub;
  final String? badge;
  final bool danger;
  final bool chevron;
  final VoidCallback? onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    this.sub,
    this.badge,
    this.danger = false,
    this.chevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _C.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger ? _C.dangerPale : _C.frost,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: danger ? _C.danger : _C.ink,
                      )),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: const TextStyle(
                            fontSize: 11, color: _C.mist)),
                  ],
                ],
              ),
            ),
            if (badge != null && badge!.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _C.danger,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
            ],
            if (chevron)
              const Icon(Icons.chevron_right, size: 18, color: _C.mist),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Root page
// ═════════════════════════════════════════════════════════════════════════════

class ProfileMenuPage extends StatefulWidget {
  const ProfileMenuPage({super.key});

  @override
  State<ProfileMenuPage> createState() => _ProfileMenuPageState();
}

class _ProfileMenuPageState extends State<ProfileMenuPage> {
  String _screen = "profile";
  _CaseItem? _activeCase;

  _AdminUser? _user;
  bool _loadingUser = true;
  String? _userError;

  // Menu counters (mirrors user panel’s savedAdvocatesCount / questionsCount)
  int _savedAdvocatesCount = 0;
  int _questionsCount = 0;

  // Whether the current user has an admin row (used for Identity sub-label)
  Map<String, dynamic>? _adminRow;
  bool _adminRowLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadEverything() async {
    await _loadUser();
    await _loadAdminRow();
    await _loadSavedAdvocatesCount();
  }

  Future<void> _loadSavedAdvocatesCount() async {
    try {
      final me = await AuthService.getUserId();
      BookmarkService.setCurrentUser(me);
      final count = await BookmarkService.count();
      if (!mounted) return;
      setState(() => _savedAdvocatesCount = count);
    } catch (_) {
      // Silently ignore — non-critical
    }
  }

  Future<void> _loadUser() async {
    setState(() {
      _loadingUser = true;
      _userError = null;
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      if (token == null || userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _userError = 'Please log in to view your profile';
        });
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. User basics
      Map<String, dynamic> userJson = const {};
      try {
        final res = await http.get(
          Uri.parse('${BASEURL.Urls().baseURL}user/search?userId=$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          userJson = _asMap(jsonDecode(res.body));
        } else {
          if (!mounted) return;
          setState(() {
            _loadingUser = false;
            _userError = 'Failed to load profile (${res.statusCode})';
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingUser = false;
          _userError = 'Failed to load profile';
        });
        return;
      }

      // 2. Contact
      Map<String, dynamic> contactJson = const {};
      try {
        final res = await http.get(
          Uri.parse(
              '${BASEURL.Urls().baseURL}user/contact-info/user?userId=$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          contactJson = _asMap(jsonDecode(res.body));
        }
      } catch (_) {}

      // 3. Location
      Map<String, dynamic> locationJson = const {};
      try {
        final res = await http.get(
          Uri.parse(
              '${BASEURL.Urls().baseURL}userLocation/findByUserId/$userId'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          locationJson = _asMap(jsonDecode(res.body));
        }
      } catch (_) {}

      final profile = _AdminUser.fromApis(
        user: userJson,
        contact: contactJson,
        location: locationJson,
      );

      if (!mounted) return;
      setState(() {
        _user = profile;
        _loadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
        _userError = 'Error loading profile: $e';
      });
    }
  }

  /// Fetch the current admin's centre entry (used for Identity sub-label).
  Future<void> _loadAdminRow() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    if (token == null || userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${BASEURL.Urls().baseURL}admin/by-user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = _asMap(jsonDecode(res.body));
        if (!mounted) return;
        setState(() {
          _adminRow = data;
          _adminRowLoaded = true;
        });
      } else {
        if (!mounted) return;
        setState(() => _adminRowLoaded = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _adminRowLoaded = true);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _setScreen(String s) => setState(() => _screen = s);

  Future<void> _openSeeMyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SeeMyProfile()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
    await _loadUser();
  }

  Future<void> _openUpdateProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpdateProfile()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
    await _loadUser();
    await _loadAdminRow();
  }

  // ── Legal Activity destinations (real user-panel pages) ─────────────────
  Future<void> _openCaseHomePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaseHomePage()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openSavedAdvocates() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedAdvocatesPage()),
    );
    if (!mounted) return;

    try {
      final count = await BookmarkService.count();
      if (!mounted) return;
      setState(() {
        _savedAdvocatesCount = count;
        _screen = "profile";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _screen = "profile");
    }
  }

  Future<void> _openMyQuestions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyQuestionsPage()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  // ── Support destinations ────────────────────────────────────────────────
  Future<void> _openFreeConsultant() async {
    final user = _user;

    if (user == null || _s(user.id).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User information not available. Please try again."),
          backgroundColor: Colors.orange,
        ),
      );
      if (!mounted) return;
      setState(() => _screen = "profile");
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FreeConsultantPage(
          currentUserId: user.id,
          currentUserName: user.displayName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  Future<void> _openAboutUkil() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutUkilScreen()),
    );
    if (!mounted) return;
    setState(() => _screen = "profile");
  }

  // ── Account actions ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("This action is permanent. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    final token = prefs.getString("jwt_token");

    if (userId == null) return;

    final url = Uri.parse(
        "${BASEURL.Urls().baseURL}user/delete/$userId?tryingToDelete=$userId");

    try {
      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.body)));
        await AuthService.logout();
        if (mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account deletion failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Delete error: $e")));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ivory,
      body: SafeArea(child: _buildScreen()),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case "profile":
        return _buildProfileMain();

      // ── Account ────────────────────────────────────────────────────
      case "personalInfo":
        return _buildPersonalInfo();
      case "contactInfo":
        return _buildContactInfo();
      case "identity":
        return _buildIdentity();

      // ── Legal Activity — direct redirects to real pages ─────────────
      case "myCases":
      case "caseHistory":
        return _buildRedirect(
          title: "My Cases",
          onBack: () => _setScreen("profile"),
          onOpen: _openCaseHomePage,
        );
      case "savedAdvocates":
        return _buildRedirect(
          title: "Saved Advocates",
          onBack: () => _setScreen("profile"),
          onOpen: _openSavedAdvocates,
        );
      case "myQuestions":
        return _buildRedirect(
          title: "My Questions",
          onBack: () => _setScreen("profile"),
          onOpen: _openMyQuestions,
        );

      // ── Support — direct redirects to real pages ───────────────────
      case "help":
        return _buildRedirect(
          title: "Help & Support",
          onBack: () => _setScreen("profile"),
          onOpen: _openFreeConsultant,
        );
      case "about":
        return _buildRedirect(
          title: "About",
          onBack: () => _setScreen("profile"),
          onOpen: _openAboutUkil,
        );

      // ── Redirects to full pages ────────────────────────────────────
      case "myProfile":
        return _buildRedirect(
          title: "My Profile",
          onBack: () => _setScreen("profile"),
          onOpen: _openSeeMyProfile,
        );
      case "editProfile":
        return _buildRedirect(
          title: "Update Profile",
          onBack: () => _setScreen("profile"),
          onOpen: _openUpdateProfile,
        );

      case "caseDetail":
        return _buildCaseDetail();
      case "deleteAccount":
        return _buildSimplePlaceholder("Delete Account", "🗑️");
      default:
        return _buildProfileMain();
    }
  }

  // ── Main profile screen ───────────────────────────────────────────────────
  Widget _buildProfileMain() {
    if (_loadingUser) {
      return const Center(
        child: CircularProgressIndicator(color: _C.mid),
      );
    }

    if (_userError != null && _user == null) {
      return _buildErrorState(_userError!, _loadUser);
    }

    final user = _user!;

    return RefreshIndicator(
      color: _C.mid,
      onRefresh: _loadEverything,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 60),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.forest, _C.mid],
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    "My Account",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openUpdateProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "✏️ Edit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Avatar card ─────────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -46),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x211A3C2B),
                      blurRadius: 30,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const ProfileImageWidget(radius: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: _C.ink,
                            ),
                          ),
                          if (_s(user.locationName).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "📍 ${_s(user.locationName)}",
                              style: const TextStyle(
                                  fontSize: 12, color: _C.mid),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (_s(user.email).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "📧 ${_s(user.email)}",
                              style: const TextStyle(
                                  fontSize: 11, color: _C.mist),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Account ─────────────────────────────────────────────────
            _sectionLabel("Account"),
            _menuGroup([
              _MenuRow(
                icon: "👤",
                label: "Personal Information",
                sub: "Name, Email, Phone",
                onTap: () => _setScreen("personalInfo"),
              ),
              _MenuRow(
                icon: "📱",
                label: "Contact Details",
                sub: "Phone, Email, Location",
                onTap: () => _setScreen("contactInfo"),
              ),
              _MenuRow(
                icon: "🪪",
                label: "Identity & Verification",
                sub: _adminRowLoaded
                    ? (_adminRow == null || _adminRow!.isEmpty
                        ? "Account status"
                        : "Verified admin")
                    : "Loading…",
                onTap: () => _setScreen("identity"),
              ),
            ]),

            // ── Legal Activity (real navigation) ───────────────────────
            _sectionLabel("Legal Activity"),
            _menuGroup([
              _MenuRow(
                icon: "⚖️",
                label: "My Cases",
                sub: "View and manage your legal cases",
                onTap: () => _setScreen("myCases"),
              ),
              _MenuRow(
                icon: "❤️",
                label: "Saved Advocates",
                sub: _savedAdvocatesCount == 0
                    ? "None saved"
                    : "$_savedAdvocatesCount advocates bookmarked",
                onTap: () => _setScreen("savedAdvocates"),
              ),
              _MenuRow(
                icon: "💬",
                label: "My Questions",
                sub: _questionsCount == 0
                    ? "None posted"
                    : "$_questionsCount questions posted",
                onTap: () => _setScreen("myQuestions"),
              ),
              _MenuRow(
                icon: "📋",
                label: "Case History",
                sub: "Complete legal record",
                onTap: () => _setScreen("caseHistory"),
              ),
            ]),

            // ── Support (real navigation) ─────────────────────────────
            _sectionLabel("Support"),
            _menuGroup([
              _MenuRow(
                icon: "❓",
                label: "Help & Support",
                sub: "FAQs, contact, report issue",
                onTap: () => _setScreen("help"),
              ),
              _MenuRow(
                icon: "ℹ️",
                label: "About",
                sub: "Version info · Terms · Privacy",
                onTap: () => _setScreen("about"),
              ),
            ]),

            // ── Danger zone ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.line),
                ),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: "🚪",
                      label: "Logout",
                      danger: true,
                      onTap: _logout,
                    ),
                    _MenuRow(
                      icon: "🗑️",
                      label: "Delete Account",
                      sub: "Permanently remove your account",
                      danger: true,
                      onTap: _deleteAccount,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.mist,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _menuGroup(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  // ── Personal Info ────────────────────────────────────────────────────────
  Widget _buildPersonalInfo() {
    final u = _user;
    if (u == null) {
      return const Center(child: CircularProgressIndicator(color: _C.mid));
    }

    return Column(
      children: [
        _BackHeader(
          title: "Personal Information",
          onBack: () => _setScreen("profile"),
          action: GestureDetector(
            onTap: _openUpdateProfile,
            child: const Text(
              "Edit",
              style: TextStyle(
                color: _C.mid,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _infoCard("Basic Information", [
                  _InfoRow(
                    label: "Full Name",
                    value: u.displayName,
                    icon: "👤",
                  ),
                  _InfoRow(label: "Username", value: u.name, icon: "🏷"),
                  _InfoRow(label: "Email", value: u.email, icon: "📧"),
                  _InfoRow(label: "Phone", value: u.phone, icon: "📱"),
                  _InfoRow(
                      label: "Location", value: u.locationName, icon: "📍"),
                ]),
                const SizedBox(height: 14),
                _infoCard("Account Status", [
                  _InfoRow(
                      label: "Account Type", value: "Admin", icon: "🎫"),
                  _InfoRow(
                    label: "Verification",
                    value: (_adminRow != null && _adminRow!.isNotEmpty)
                        ? "Admin verified"
                        : "Not verified",
                    icon: "🛡",
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openUpdateProfile,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Edit Personal Information"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Contact Info ─────────────────────────────────────────────────────────
  Widget _buildContactInfo() {
    final u = _user;
    if (u == null) {
      return const Center(child: CircularProgressIndicator(color: _C.mid));
    }

    final lat = u.lattitude != null ? u.lattitude!.toStringAsFixed(5) : '';
    final lng = u.longitude != null ? u.longitude!.toStringAsFixed(5) : '';

    return Column(
      children: [
        _BackHeader(
          title: "Contact Details",
          onBack: () => _setScreen("profile"),
          action: GestureDetector(
            onTap: _openUpdateProfile,
            child: const Text(
              "Edit",
              style: TextStyle(
                color: _C.mid,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _infoCard("Contact Information", [
                  _InfoRow(label: "Email", value: u.email, icon: "📧"),
                  _InfoRow(label: "Phone", value: u.phone, icon: "📱"),
                  _InfoRow(
                      label: "Location",
                      value: u.locationName,
                      icon: "📍"),
                  _InfoRow(label: "Latitude", value: lat, icon: "🗺"),
                  _InfoRow(label: "Longitude", value: lng, icon: "🗺"),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Identity ─────────────────────────────────────────────────────────────
  Widget _buildIdentity() {
    return _IdentityRouter(
      userId: _user?.id ?? '',
      onBack: () => _setScreen("profile"),
      onAfterRegister: _loadUser,
    );
  }

  // ── Case Detail (kept for parity) ───────────────────────────────────────
  Widget _buildCaseDetail() {
    final c = _activeCase;
    if (c == null) return const SizedBox.shrink();
    return _CaseDetailView(
      caseItem: c,
      onBack: () => _setScreen("myCases"),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _buildSimplePlaceholder(String title, String emoji) {
    return Column(
      children: [
        _BackHeader(title: title, onBack: () => _setScreen("profile")),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 14),
                  Text(
                    "$title — coming soon",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "This screen is a placeholder.\nWire up the real API here later.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _C.mist),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRedirect({
    required String title,
    required VoidCallback onBack,
    required Future<void> Function() onOpen,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onOpen());
    return Column(
      children: [
        _BackHeader(title: title, onBack: onBack),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: _C.mid),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.frost,
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _C.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _C.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.slate, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.forest,
                foregroundColor: Colors.white,
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _IdentityRouter — decides between registration and profile
// ═════════════════════════════════════════════════════════════════════════════

class _IdentityRouter extends StatefulWidget {
  final String userId;
  final VoidCallback onBack;
  final Future<void> Function() onAfterRegister;

  const _IdentityRouter({
    required this.userId,
    required this.onBack,
    required this.onAfterRegister,
  });

  @override
  State<_IdentityRouter> createState() => _IdentityRouterState();
}

class _IdentityRouterState extends State<_IdentityRouter> {
  final DirectorService _directorService = DirectorService();

  bool _loading = true;
  String? _error;
  List<DirectorResponse> _directors = [];

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'User not logged in';
      });
      return;
    }

    try {
      final list = await _directorService.getDirectorByUserId(widget.userId);
      if (!mounted) return;
      setState(() {
        _directors = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openRegistration() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectorRegistrationScreen(userId: widget.userId),
      ),
    );
    if (!mounted) return;
    await _check();
    await widget.onAfterRegister();
  }

  Future<void> _openProfile(DirectorResponse d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectorProfilePage(
          directorId: d.id,
          userId: widget.userId,
        ),
      ),
    );
    if (!mounted) return;
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.arrow_back,
                      size: 22, color: _C.forest),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Identity & Verification",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.mid),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: _C.danger),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.slate, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _check,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.forest,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (_directors.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.forest, _C.mid],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Text("🛡", style: TextStyle(fontSize: 40)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verification Pending",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Register as a director to unlock all features.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _identityInfoCard("Director Status", [
              _identityInfoRow("Status", "Not registered", "✅"),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openRegistration,
                icon: const Icon(Icons.app_registration, size: 18),
                label: const Text("Register as Director"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final primary = _directors.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.forest, _C.mid],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text("🛡", style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Verified Director",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _s(primary.position).isNotEmpty
                            ? _s(primary.position)
                            : "Director",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _identityInfoCard("Director Information", [
            _identityInfoRow("Full Name",
                _s(primary.fullName).isEmpty ? "—" : _s(primary.fullName),
                "👤"),
            _identityInfoRow("Position",
                _s(primary.position).isEmpty ? "—" : _s(primary.position),
                "💼"),
            _identityInfoRow("NID Number",
                _s(primary.nidNumber).isEmpty ? "—" : _s(primary.nidNumber),
                "🪪"),
            _identityInfoRow(
                "Mobile",
                _s(primary.mobileNumber ?? primary.phone).isEmpty
                    ? "—"
                    : _s(primary.mobileNumber ?? primary.phone),
                "📱"),
            _identityInfoRow(
                "Email",
                _s(primary.email ?? primary.directorEmail).isEmpty
                    ? "—"
                    : _s(primary.email ?? primary.directorEmail),
                "📧"),
            _identityInfoRow(
                "Location",
                _s(primary.locationName).isEmpty
                    ? "—"
                    : _s(primary.locationName),
                "📍"),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openProfile(primary),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text("Open Director Profile"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityInfoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _C.frost,
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _C.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _identityInfoRow(String label, String value, String icon) {
    final raw = value.trim();
    final display = raw.isEmpty ? '—' : raw;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: _C.mist)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Case Detail sub-view — unchanged design
// ═════════════════════════════════════════════════════════════════════════════

class _CaseDetailView extends StatefulWidget {
  final _CaseItem caseItem;
  final VoidCallback onBack;
  const _CaseDetailView({required this.caseItem, required this.onBack});

  @override
  State<_CaseDetailView> createState() => _CaseDetailViewState();
}

class _CaseDetailViewState extends State<_CaseDetailView> {
  String _tab = "Overview";
  static const _tabs = ["Overview", "Timeline", "Documents", "Payment"];

  @override
  Widget build(BuildContext context) {
    final c = widget.caseItem;
    return Column(
      children: [
        _BackHeader(title: "Case Details", onBack: widget.onBack),
        Container(
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((t) {
                final selected = _tab == t;
                return GestureDetector(
                  onTap: () => setState(() => _tab = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected
                              ? _C.forest
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: selected ? _C.forest : _C.mist,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1, color: _C.line),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _caseHeaderCard(c),
                const SizedBox(height: 14),
                if (_tab == "Overview") ...[
                  _advocateCard(c),
                  const SizedBox(height: 14),
                  _progressCard(c),
                ] else
                  _placeholderForTab(_tab),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _caseHeaderCard(_CaseItem c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _C.ink,
                        )),
                    const SizedBox(height: 3),
                    Text(c.id,
                        style: const TextStyle(
                            fontSize: 11, color: _C.mist)),
                  ],
                ),
              ),
              _StatusBadge(status: c.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.frost,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _kv("Type", c.type)),
                    Expanded(child: _kv("Filed", c.filed)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _kv("Next Hearing", c.hearing)),
                    Expanded(child: _kv("Paid", c.paid)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 10, color: _C.mist)),
        const SizedBox(height: 2),
        Text(v,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _C.ink,
            )),
      ],
    );
  }

  Widget _advocateCard(_CaseItem c) {
    final initials = c.advocate
        .split(" ")
        .where((s) => s.isNotEmpty)
        .skip(1)
        .map((s) => s[0])
        .join();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your Advocate",
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              _SealAvatar(
                  initials: initials.isEmpty ? '?' : initials, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.advocate,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(c.type,
                        style: const TextStyle(
                            fontSize: 12, color: _C.mist)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: 16),
                  label: const Text("Chat"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.forest,
                    side: const BorderSide(color: _C.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text("Call"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressCard(_CaseItem c) {
    const steps = [
      "Filed",
      "Accepted",
      "Under Review",
      "Hearing Set",
      "Hearing",
      "Resolved",
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Case Progress",
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 12),
          ...List.generate(steps.length, (i) {
            final done = i < c.progress;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < steps.length - 1 ? 14 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? _C.mid : _C.line,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          done ? "✓" : "${i + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Container(
                          width: 2,
                          height: 14,
                          margin: const EdgeInsets.only(top: 4),
                          color: done ? _C.mid : _C.line,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: done
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: done ? _C.ink : _C.mist,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _placeholderForTab(String tab) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text("$tab — coming soon",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _C.ink,
              )),
          const SizedBox(height: 6),
          const Text("Wire up the real content here later.",
              style: TextStyle(fontSize: 12, color: _C.mist)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}