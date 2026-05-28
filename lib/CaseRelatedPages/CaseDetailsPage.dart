import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'MyCasesPage.dart';
import 'SeeAllCases.dart';
import 'case_judgment_service.dart';
import 'CaseJudgmentModel.dart';
import './AppealCasePage.dart';
import './case_model.dart';
import '../Utils/BaseURL.dart' as BASE_URL;
import '../Auth/AuthService.dart';
import 'AttachmentViewer.dart';
import 'case_tracking.dart';
import '../PageTransition.dart';

class CaseDetailsPage extends StatefulWidget {
  final CaseModel caseModel;
  final String? userId;
  final VoidCallback? onDeleted;

  const CaseDetailsPage({
    super.key,
    required this.caseModel,
    this.userId,
    this.onDeleted,
  });

  @override
  State<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends State<CaseDetailsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final String baseUrl = "${BASE_URL.Urls().baseURL}case";

  // List of available transition types for random selection
  final List<PageTransitionType> _transitionTypes = AnimatedRoute.getCompanySafeAnimations();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  PageTransitionType _getRandomTransition() {
    final random = DateTime.now().millisecondsSinceEpoch % _transitionTypes.length;
    return _transitionTypes[random];
  }

  void _navigateWithRandomTransition(BuildContext context, Widget page) {
    NavigationHelper.push(
      context,
      page,
      transitionType: _getRandomTransition(),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> openAttachment(String attachmentId, {bool view = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final jwtToken = prefs.getString('jwt_token') ?? '';

    final url = Uri.parse(
      '${BASE_URL.Urls().baseURL}case/attachment/$attachmentId',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$attachmentId');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } else {
      throw Exception('Failed to download attachment: ${response.statusCode}');
    }
  }

  Future<CaseJudgment?> loadJudgment() {
    return CaseJudgmentService.getByCase(widget.caseModel.id);
  }

  Future<bool> isMyCase() async {
    final prefs = await SharedPreferences.getInstance();
    final myUserId = prefs.getString('userId');
    return myUserId != null && myUserId == widget.caseModel.userId;
  }

  Future<bool> deleteCase(BuildContext context) async {
    final url = "$baseUrl/${widget.caseModel.id}/${widget.caseModel.userId}";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "content-type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Case deleted successfully")),
        );
        return true;
      } else {
        throw body["error"] ?? "Delete failed";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return false;
    }
  }

  Future<bool?> confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Case",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete this case?\nThis action cannot be undone.",
          style: GoogleFonts.inter(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext, true);
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.grey.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(
                      "Deleting Case",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          "Deleting case...\nPlease wait",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.grey.shade300),
                        ),
                      ],
                    ),
                  ),
                );

                final success = await deleteCase(context);
                if (context.mounted) Navigator.pop(context);

                if (success) {
                  widget.onDeleted?.call();
                  if (context.mounted) {
                    _navigateWithRandomTransition(
                      context,
                      MyCasesPage(userId: widget.caseModel.userId),
                    );
                  }
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon ?? Icons.info, size: 20, color: Colors.deepPurple.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.insert_drive_file, color: Colors.deepPurple.shade600, size: 20),
        ),
        title: Text(
          id.length > 30 ? '${id.substring(0, 27)}...' : id,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.deepPurple.shade600, size: 20),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  final token = prefs.getString('jwt_token') ?? '';
                  _navigateWithRandomTransition(
                    context,
                    CaseAttachmentView(attachmentId: id, jwtToken: token),
                  );
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.download, color: Colors.deepPurple.shade600, size: 20),
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  final token = prefs.getString('jwt_token') ?? '';
                  _navigateWithRandomTransition(
                    context,
                    CaseAttachmentView(attachmentId: id, jwtToken: token),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "Case Details",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E), // Deep Navy
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E), // Deep Navy
                Color(0xFF283593), // Indigo
                Color(0xFF3949AB), // Lighter Indigo
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Case Header Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A237E), // Deep Navy
                      Color(0xFF283593), // Indigo
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.gavel, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.caseModel.caseName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Case ID: ${widget.caseModel.id.substring(0, 8)}...",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Case Information Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Case Information",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _infoRow("Case Type", widget.caseModel.caseType, icon: Icons.category),
                      _infoRow("Client", widget.caseModel.userName, icon: Icons.person),
                      _infoRow("Advocate", widget.caseModel.advocateName ?? "Not Assigned", icon: Icons.gavel),
                      _infoRow("Issued Date", widget.caseModel.issuedTime, icon: Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Attachments Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.attachment, size: 20, color: Colors.deepPurple.shade600),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Attachments",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${widget.caseModel.attachmentsId.length} files",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.caseModel.attachmentsId.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.attach_file, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  "No attachments available",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...widget.caseModel.attachmentsId.map((id) => _buildAttachmentTile(id)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              FutureBuilder<bool>(
                future: isMyCase(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }

                  final isOwner = snapshot.hasData && snapshot.data == true;

                  return Column(
                    children: [
                      // Case Tracking Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.track_changes),
                          label: Text(
                            "Case Tracking",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.grey.shade900,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Loading Case Tracking...\nPlease wait",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('jwt_token') ?? '';
                            String? advocateUserId;

                            final response = await http.get(
                              Uri.parse(
                                "${BASE_URL.Urls().baseURL}advocate/${widget.caseModel.advocateId}",
                              ),
                              headers: {
                                "content-type": "application/json",
                                "Authorization": "Bearer $token",
                              },
                            );

                            if (response.statusCode == 200) {
                              final body = jsonDecode(response.body);
                              advocateUserId = body["userId"];
                            }

                            if (context.mounted) Navigator.pop(context);

                            _navigateWithRandomTransition(
                              context,
                              CaseTracking(
                                caseId: widget.caseModel.id,
                                caseName: widget.caseModel.caseName,
                                caseLawyer: widget.caseModel.advocateName,
                                issuedTime: widget.caseModel.issuedTime,
                                token: token,
                                advocateUserId: advocateUserId,
                                userName: widget.caseModel.userName,
                                userId: widget.caseModel.userId == widget.userId ? widget.userId : null,
                                advocateId: widget.caseModel.advocateId,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Delete Button (only for owner)
                      if (isOwner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: Text(
                              "Delete Case",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () => confirmDelete(context),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Appeal Button
                      FutureBuilder<CaseJudgment?>(
                        future: loadJudgment(),
                        builder: (context, snapshot) {
                          if (!isOwner || !snapshot.hasData || snapshot.data == null) {
                            return const SizedBox();
                          }

                          final judgment = snapshot.data!;
                          final today = DateTime.now();
                          final judgmentDate = judgment.date;
                          final canAppeal = judgmentDate.isBefore(
                            DateTime(today.year, today.month, today.day),
                          );

                          if (!canAppeal) return const SizedBox();

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.gavel),
                              label: Text(
                                "Case Appeal",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                final token = prefs.getString('jwt_token') ?? '';
                                _navigateWithRandomTransition(
                                  context,
                                  AppealCasePage(
                                    token: token,
                                    caseId: widget.caseModel.id,
                                    userId: widget.userId ?? '',
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}