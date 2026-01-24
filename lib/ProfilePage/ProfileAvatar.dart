import 'package:advocatechaiadmin/ProfilePage/ProfileImageWidget.dart';
import 'package:flutter/material.dart';
import 'package:advocatechaiadmin/Auth/AuthService.dart';
import 'package:advocatechaiadmin/ProfilePage/ProfileMenuPage.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key});

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  void checkLogin() async {
    loggedIn = await AuthService.isLoggedIn();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileMenuPage()),
        );
      },
      child: ProfileImageWidget()
    );
  }
}
