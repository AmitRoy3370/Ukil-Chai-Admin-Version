import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as baseURL;
import 'answer_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnswerTile extends StatelessWidget {
  final AnswerResponse answer;
  const AnswerTile({required this.answer, super.key});

  Future<String> getNameFromUser(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = "${baseURL.Urls().baseURL}user/search?userId=$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {"content-type": "application/json", "Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body["name"] ?? "";
    }
    return "";
  }

  Future<String> getNameFromAdvocate(String advocateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final url = "${baseURL.Urls().baseURL}advocate/$advocateId";
    final response = await http.get(
      Uri.parse(url),
      headers: {"content-type": "application/json", "Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final userId = body["userId"];
      return getNameFromUser(userId);
    }
    return "";
  }

  String _getExtensionFromContentType(String? contentType) {
    if (contentType == null) return ".bin";
    if (contentType.contains("pdf")) return ".pdf";
    if (contentType.contains("jpeg")) return ".jpeg";
    if (contentType.contains("jpg")) return ".jpg";
    if (contentType.contains("png")) return ".png";
    if (contentType.contains("word")) return ".docx";
    return ".bin";
  }

  Future<void> openAttachment(BuildContext context, String attachmentId) async {
    try {
      final url = "${baseURL.Urls().baseURL}answers/download?attachmentId=$attachmentId";
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download failed")));
        return;
      }

      String fileName = "attachment";
      final disposition = response.headers['content-disposition'];
      if (disposition != null) {
        final match = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
        if (match != null) fileName = match.group(1)!;
      }

      final contentType = response.headers['content-type'] ?? "application/octet-stream";
      if (!fileName.contains(".")) fileName += _getExtensionFromContentType(contentType);

      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..setAttribute("download", fileName)..click();
        html.Url.revokeObjectUrl(url);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Attachment error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAttachment = answer.attachmentId != null && answer.attachmentId!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.05),
              Colors.blue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Advocate Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified, size: 14, color: Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer.advocateName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Answer Message
            Text(
              answer.message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),

            // Attachment - Standard visibility based on existence
            if (hasAttachment)
              InkWell(
                onTap: () => openAttachment(context, answer.attachmentId!),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        "View Attachment",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
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
}