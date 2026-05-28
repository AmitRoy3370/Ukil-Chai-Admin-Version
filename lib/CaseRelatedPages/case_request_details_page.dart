import 'dart:convert';
import 'dart:math';

import 'package:advocatechaiadmin/Auth/AuthService.dart';
import 'package:advocatechaiadmin/CaseRelatedPages/CaseRequestAttachmentViewer.dart';
import 'package:advocatechaiadmin/Utils/AdvocateSpeciality.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import './case_request.dart';
import './case_request_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../PageTransition.dart';

class CaseRequestDetailsPage extends StatelessWidget {
  final CaseRequest caseRequest;
  final service = CaseRequestService();

  CaseRequestDetailsPage({super.key, required this.caseRequest});

  // List of friendly animations (excluding mirror/flip effects)
  final List<PageTransitionType> _friendlyAnimations = AnimatedRoute.getCompanySafeAnimations();

  PageTransitionType _getRandomAnimation() {
    final random = Random().nextInt(_friendlyAnimations.length);
    return _friendlyAnimations[random];
  }

  void openAttachment(String id) {
    launchUrl(
      Uri.parse("${BASE_URL.Urls().baseURL}case-request/attachment/view/$id"),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<String> getAdvocateName(String advocateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = "${BASE_URL.Urls().baseURL}advocate/$advocateId";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final userId = body["userId"];
      return getNameFromUser(userId);
    } else {
      return "";
    }
  }

  Future<String> getNameFromUser(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final url = "${BASE_URL.Urls().baseURL}user/search?userId=$userId";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body["name"] ?? "";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Case Details",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade600,
                    Colors.blue.shade600,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      caseRequest.caseType.icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    caseRequest.caseName,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caseRequest.caseType.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildInfoCard(
                    title: "Case Status",
                    icon: Icons.info_outline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: caseRequest.requestedAdvocateId != null
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        caseRequest.requestedAdvocateId != null
                            ? "REQUESTED"
                            : "PENDING",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: caseRequest.requestedAdvocateId != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Requested By Card
                  _buildInfoCard(
                    title: "Requested By",
                    icon: Icons.person_outline,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.purple.withOpacity(0.1),
                          child: Text(
                            caseRequest.userName.isNotEmpty
                                ? caseRequest.userName[0].toUpperCase()
                                : "U",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            caseRequest.userName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Request Date Card
                  _buildInfoCard(
                    title: "Request Date",
                    icon: Icons.calendar_today,
                    child: Text(
                      _formatDate(caseRequest.requestDate),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assigned Advocate Card (if exists)
                  if (caseRequest.requestedAdvocateId != null &&
                      caseRequest.requestAdvocateName != null) ...[
                    _buildInfoCard(
                      title: "Assigned Advocate",
                      icon: Icons.verified_user,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Icon(
                              Icons.verified,
                              size: 20,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              caseRequest.requestAdvocateName!,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Attachments Card
                  _buildInfoCard(
                    title: "Attachments",
                    icon: Icons.attach_file,
                    child: caseRequest.attachmentId.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                "No attachments",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: caseRequest.attachmentId.map((id) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.insert_drive_file,
                                      color: Colors.purple,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    "Attachment ${id.substring(0, min(8, id.length))}...",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.open_in_new,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    onPressed: () async {
                                      SharedPreferences prefs =
                                          await SharedPreferences.getInstance();
                                      String jwtToken =
                                          prefs.getString('jwt_token') ?? '';

                                      await NavigationHelper.push(
                                        context,
                                        CaseRequestAttachmentViewer(
                                          attachmentId: id,
                                          jwtToken: jwtToken,
                                        ),
                                        transitionType: _getRandomAnimation(),
                                        duration: const Duration(milliseconds: 400),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Back"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
             
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.purple),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

int min(int a, int b) => a < b ? a : b;