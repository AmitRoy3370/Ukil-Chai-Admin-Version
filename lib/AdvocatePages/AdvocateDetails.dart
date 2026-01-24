import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;

import 'package:advocatechaiadmin/AdvocatePages/AdvocateDetailsModel.dart';
import 'package:advocatechaiadmin/Auth/AuthService.dart';
import 'package:advocatechaiadmin/Utils/BaseURL.dart' as baseURL;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'dart:convert';

class AdvocateDetails extends StatefulWidget {
  final AdvocateDetailsModel advocateDetailsModel;

  const AdvocateDetails({super.key, required this.advocateDetailsModel});

  @override
  State<AdvocateDetails> createState() => AdvocateDetailsState();
}

class AdvocateDetailsState extends State<AdvocateDetails> {
  /// ================= PROFILE IMAGE =================
  Future<Uint8List?> fetchProfileImage() async {
    final imageId = widget.advocateDetailsModel.profileImageId;
    if (imageId == null || imageId.isEmpty) return null;

    final token = await AuthService.getToken();

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}user/download/$imageId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// ================= CV FETCH =================
  Future<Uint8List?> fetchCv() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocate/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  void downloadPdfWeb(List<int> bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "file.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> downloadPdfMobile(List<int> bytes) async {
    final dir = await getTemporaryDirectory();

    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }

  /// ================= OPEN CV =================
  Future<void> downloadAndOpenCV() async {
    final token = await AuthService.getToken();
    final userId = widget.advocateDetailsModel.userId;

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}advocate/cv/$userId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No CV available")));
      return;
    }

    final bytes = response.bodyBytes;

    // 🌐 WEB
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", "advocate_cv.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
      return;
    }

    // 📱 MOBILE
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/advocate_cv.pdf');

    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("Advocate Details"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ================= PROFILE =================
            Center(
              child: Column(
                children: [
                  FutureBuilder<Uint8List?>(
                    future: fetchProfileImage(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircleAvatar(
                          radius: 55,
                          child: Icon(Icons.person, size: 55),
                        );
                      }

                      return CircleAvatar(
                        radius: 55,
                        backgroundImage: MemoryImage(snapshot.data!),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.advocateDetailsModel.name ?? "Unknown Advocate",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${widget.advocateDetailsModel.experience ?? 0} years experience",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _section("Contact Information", [
              _row(Icons.email, widget.advocateDetailsModel.email),
              _row(Icons.phone, widget.advocateDetailsModel.phone),
            ]),

            _section("Location", [
              _row(Icons.location_on, widget.advocateDetailsModel.locationName),
              _row(Icons.map, "Lat: ${widget.advocateDetailsModel.lattitude}"),
              _row(
                Icons.map_outlined,
                "Lng: ${widget.advocateDetailsModel.longitude}",
              ),
            ]),

            _section("Professional Info", [
              _row(
                Icons.badge,
                "License: ${widget.advocateDetailsModel.licenseKey}",
              ),
            ]),

            _listSection(
              "Specialities",
              (widget.advocateDetailsModel.advocateSpeciality).cast<String>(),
            ),

            _listSection(
              "Degrees",
              (widget.advocateDetailsModel.degrees).cast<String>(),
            ),

            _listSection(
              "Working Experience",
              (widget.advocateDetailsModel.workingExperiences).cast<String>(),
            ),

            const SizedBox(height: 20),

            /// ================= CV BUTTON =================
            ElevatedButton.icon(
              onPressed: downloadAndOpenCV,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("View CV"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= UI HELPERS =================
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.deepOrange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? "Not available",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection(String title, List<String> items) {
    return _section(
      title,
      items.isEmpty
          ? [
              const Text(
                "No data available",
                style: TextStyle(color: Colors.grey),
              ),
            ]
          : items.map((e) => _row(Icons.check_circle, e)).toList(),
    );
  }
}
