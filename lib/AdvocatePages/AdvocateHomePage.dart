import 'dart:convert';
import 'package:advocatechaiadmin/AdvocatePages/AdvocateFilterPage.dart';
import 'package:advocatechaiadmin/AdvocatePages/advocate_join_request_filter_pages.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Auth/AuthService.dart';

import '../Utils/BaseURL.dart' as BASE_URL;
import '../Utils/AdvocateSpeciality.dart';

class AdvocateHomePage extends StatefulWidget {
  const AdvocateHomePage({super.key});

  @override
  State<AdvocateHomePage> createState() => _AdvocateHomePage();
}

class _AdvocateHomePage extends State<AdvocateHomePage> {
  List<Widget> pages = [AdvocateFilterPage(), AdvocateJoinRequestFilterPage()];
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Advocate Home Page",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
      ),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: " All Advocate",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: " Advocate request",
          ),
        ],
        currentIndex: index,
        onTap: (value) {
          setState(() {
            index = value;
          });
        },
      ),
    );
  }
}
