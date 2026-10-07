// lib/NotificationPages/notification_page.dart
//
// Admin Notification Page — now with full tap-to-navigate behaviour
// matching the user panel.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/BaseURL.dart' as BASE_URL;
import 'notification_model.dart';

// ── Navigation targets (same as user panel) ─────────────────────────────────
import '../ProfilePage/SeeMyProfile.dart';
import '../ChatRelatedPages/chat_screen.dart';
import '../GroupChat/GroupChatScreen.dart';
import '../CaseRelatedPages/CaseDetailsPage.dart';
import '../CaseRelatedPages/case_service.dart';
import '../CaseRelatedPages/case_model.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<NotificationModel> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();

    loadNotifications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> loadNotifications() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');
      final String? token = prefs.getString('jwt_token');

      if (userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          notifications = [];
          loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}notifications/unread/$userId"),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final parsed = data
            .map((e) =>
                NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList()
            .reversed
            .toList();

        if (!mounted) return;
        setState(() {
          notifications = parsed;
          loading = false;
        });
        _animationController
          ..reset()
          ..forward();
      } else {
        if (!mounted) return;
        setState(() {
          notifications = [];
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        notifications = [];
        loading = false;
      });
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    try {
      await http.put(
        Uri.parse(
            "${BASE_URL.Urls().baseURL}notifications/mark-read/$notificationId"),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      notifications.removeWhere((n) => n.id == notificationId);
    });
  }

  Future<void> deleteNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    try {
      await http.delete(
        Uri.parse(
            "${BASE_URL.Urls().baseURL}notifications/delete/$notificationId"),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      notifications.removeWhere((n) => n.id == notificationId);
    });
  }

  // ── Time formatting ─────────────────────────────────────────────────────
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 7) {
      return '${diff.inDays ~/ 7} সপ্তাহ আগে';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} দিন আগে';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ঘন্টা আগে';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} মিনিট আগে';
    } else {
      return 'এখনই';
    }
  }

  // ── Navigation: identical logic to the user panel ───────────────────────
  Future<void> _navigateFromNotification(NotificationModel notification) async {
    if (!mounted) return;

    // 1) Mark as read FIRST, then navigate.
    if (!notification.isRead) {
      await markAsRead(notification.id);
    }

    if (!mounted) return;

    final List<String> destinations = notification.destinations;
    final Map<String, String> params = notification.params;

    if (destinations.isEmpty) return;

    final String className = destinations.last;

    try {
      // ── SeeMyProfile / ProfilePage ────────────────────────────────────
      if (className == 'SeeMyProfile' || className == 'ProfilePage') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SeeMyProfile()),
        );
        return;
      }

      // ── CaseDetailsPage ──────────────────────────────────────────────
      if (className == 'CaseDetailsPage') {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('jwt_token');
        final String? caseId = params["caseId"];

        if (caseId == null || token == null) {
          _showSnack('Missing caseId or token');
          return;
        }

        final CaseModel caseModel =
            await CaseService(token).findById(caseId);
        final String? userId = caseModel.userId;

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaseDetailsPage(
              caseModel: caseModel,
              userId: userId,
              onDeleted: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        );
        return;
      }

      // ── ChatScreen ───────────────────────────────────────────────────
      if (className == 'ChatScreen') {
        final String? currentUser = params["currentUser"];
        final String? otherUser = params["otherUser"];
        final String? myName = params["myName"];
        final String? othersName = params["othersName"];

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              currentUser: currentUser,
              otherUser: otherUser,
              othersName: othersName,
              myName: myName,
            ),
          ),
        );
        return;
      }

      // ── GroupChatScreen ──────────────────────────────────────────────
      if (className == 'GroupChatScreen') {
        final String? groupId = params["groupId"];
        final String? groupName = params["groupName"];
        final String? currentUserId = params["currentUserId"];
        final String? currentUserName = params["currentUserName"];

        if (groupId == null ||
            groupName == null ||
            currentUserId == null ||
            currentUserName == null) {
          _showSnack('Missing group chat parameters');
          return;
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatScreen(
              groupId: groupId,
              groupName: groupName,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              isAdmin: false,
            ),
          ),
        );
        return;
      }

      // ── Fallback ────────────────────────────────────────────────────
      _showSnack('Unknown destination: $className');
    } catch (e) {
      _showSnack('Navigation error: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("নোটিফিকেশন"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: loading && notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 16),
                  Text("নোটিফিকেশন লোড হচ্ছে..."),
                ],
              ),
            )
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "কোনো নোটিফিকেশন নেই",
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadNotifications,
                  color: Colors.green,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];

                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index * 0.05).clamp(0.0, 1.0),
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          )),
                          child: Dismissible(
                            key: Key(n.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (_) => deleteNotification(n.id),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: n.isRead
                                      ? Colors.grey.shade200
                                      : Colors.green.shade100,
                                  child: Icon(
                                    Icons.notifications_active,
                                    color: n.isRead
                                        ? Colors.grey.shade600
                                        : Colors.green.shade700,
                                  ),
                                ),
                                title: Text(
                                  n.message,
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _formatTime(n.timeStamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                // Green check button — same handler as tap.
                                trailing: n.isRead
                                    ? null
                                    : Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _navigateFromNotification(n),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(),
                                        ),
                                      ),
                                // Tapping the row does the same thing.
                                onTap: () =>
                                    _navigateFromNotification(n),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}