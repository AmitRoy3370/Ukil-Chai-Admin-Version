import '../PostRelatedPages/post_response.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './AdvocatePost.dart';
import './PostService.dart';
import './post_card.dart';

class PostFeedPage extends StatefulWidget {
  const PostFeedPage({super.key});

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage> {
  bool loading = true;
  List<PostResponse> posts = [];

  @override
  void initState() {
    super.initState();
    //loadPosts();
  }

  Future<void> loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final data = await PostService.fetchAllPosts(token);
    setState(() {
      posts = data;
      posts = posts.reversed.toList();
      loading = false;
    });
  }

  // ✅ FutureBuilder ব্যবহারের জন্য Future তৈরি করুন
  Future<List<PostResponse>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    //advocateId = prefs.getString('advocateId') ?? '';

    final data = await PostService.fetchAllPosts(token);
    // রিভার্স অর্ডার করুন (নতুন পোস্ট আগে দেখাবে)
    return data.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Advocate Posts")),
      body: FutureBuilder<List<PostResponse>>(
        future: getPosts(),
        builder: (context, snapshot) {
          // লোডিং স্টেট
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error স্টেট
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Rebuild করে আবার FutureBuilder কল হবে
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          // Data স্টেট
          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No posts available'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (_, index) {
              final post = posts[index];

              return PostCard(
                post: post,

                // ✅ onReactionChanged - PostCard এ callback পাঠান
                onReactionChanged: (reaction, action) {
                  // Reaction update handle করার জন্য
                  // PostFeedPage এ state update প্রয়োজন নেই,
                  // কারণ PostCard ই নিজের reactions update করবে
                  // কিন্তু如果需要 refresh posts, তাহলে:
                  _refreshPostAtIndex(index);
                },
                canReact: true,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refreshPostAtIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final allPosts = await PostService.fetchAllPosts(token);
    final updatedPosts = allPosts.reversed.toList();

    if (index < updatedPosts.length) {
      setState(() {
        // পুরো লিস্ট না রিলোড করে শুধু specific post টি আপডেট করুন
        // কিন্তু FutureBuilder পুরো thing re-run করবে anyway
      });
    }
  }
}
