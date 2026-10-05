import 'dart:convert';
import '../AdvocatePages/AdvocateDetailsModel.dart';
import '../AdvocatePages/AdvocateDetails.dart';
import '../PostRelatedPages/attachment_widget.dart';
import '../PostRelatedPages/PostAttachmentViewer.dart';
import '../PostRelatedPages/post_response.dart';
import '../PostRelatedPages/single_post_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../Auth/AuthService.dart';
import '../Utils/BaseURL.dart' as BASE_URL;

class PostCardHomePage extends StatefulWidget {
  final PostResponse post;

  const PostCardHomePage({super.key, required this.post});

  @override
  State<PostCardHomePage> createState() => _PostCardHomePageState();
}

class _PostCardHomePageState extends State<PostCardHomePage> {
  String? _token;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await AuthService.getToken();
    setState(() {
      _token = token;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _navigateToAttachmentViewer(String attachmentId) {
    if (_token == null || _token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view attachment')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostAttachmentView(
          attachmentId: attachmentId,
          jwtToken: _token!,
        ),
      ),
    );
  }

  void _navigateToSinglePost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePostPage(
          post: widget.post,
          canReact: true,
          onReactionChanged: (reaction, action) {
            // রিঅ্যাকশন পরিবর্তন হলে
          },
        ),
      ),
    );
  }

  // ========== অ্যাডভোকেট প্রোফাইলে নেভিগেট ==========
  Future<void> _navigateToAdvocateProfile(String advocateId) async {
    try {
      final token = await AuthService.getToken();
      
      final response = await http.get(
        Uri.parse("${BASE_URL.Urls().baseURL}advocate/$advocateId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final AdvocateDetailsModel advocate = AdvocateDetailsModel.fromJson(responseData);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvocateDetails(advocateDetailsModel: advocate),
            ),
          );
        }
      } else {
        print("❌ Failed to load advocate details: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load advocate profile')),
          );
        }
      }
    } catch (e) {
      print("❌ Error loading advocate: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading advocate profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToSinglePost,
      child: SizedBox(
        width: 280, // 🔥 ফিক্সড সাইজ
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ========== হেডার ==========
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        widget.post.advocateName.isNotEmpty
                            ? widget.post.advocateName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ========== অ্যাডভোকেটের নাম (ক্লিকযোগ্য) ==========
                          GestureDetector(
                            onTap: () => _navigateToAdvocateProfile(widget.post.advocateId),
                            child: Text(
                              widget.post.advocateFullName ?? widget.post.advocateName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            widget.post.formattedPostType,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 🔥 "View Details" বাটন
                    GestureDetector(
                      onTap: _navigateToSinglePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ========== পোস্ট কন্টেন্ট ==========
                if (widget.post.postContent.isNotEmpty)
                  _buildPostContent(),

                const SizedBox(height: 8),

                // ========== অ্যাটাচমেন্ট ==========
                if (widget.post.hasAttachment)
                  AttachmentWidget(
                    attachmentId: widget.post.attachmentId!,
                    height: 120,
                    onViewAttachment: _navigateToAttachmentViewer,
                  ),

                const SizedBox(height: 8),

                // ========== রিঅ্যাকশন এবং কমেন্ট ==========
                _buildReactionAndCommentRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostContent() {
    final text = widget.post.postContent;
    final shouldShowMore = text.length > 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shouldShowMore)
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          )
        else ...[
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[700],
            ),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Show less' : 'Show more',
              style: GoogleFonts.inter(
                color: Colors.blue.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReactionAndCommentRow() {
    final totalReactions = widget.post.totalReactions;
    final commentCount = widget.post.reactions.length;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            _showReactionDialog(context);
          },
          child: Row(
            children: [
              Icon(
                Icons.favorite,
                size: 14,
                color: totalReactions > 0
                    ? Colors.red.shade400
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(totalReactions),
                style: TextStyle(
                  fontSize: 11,
                  color: totalReactions > 0
                      ? Colors.grey.shade700
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Icon(
              Icons.comment,
              size: 14,
              color: commentCount > 0
                  ? Colors.grey.shade700
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              _formatCount(commentCount),
              style: TextStyle(
                fontSize: 11,
                color: commentCount > 0
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: _navigateToSinglePost,
          icon: Icon(
            Icons.open_in_new,
            size: 16,
            color: Colors.green.shade600,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'View Details',
        ),
      ],
    );
  }

  void _showReactionDialog(BuildContext context) {
    if (widget.post.reactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reactions yet'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reactions (${widget.post.reactions.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.post.reactions.length,
                  itemBuilder: (context, index) {
                    final reaction = widget.post.reactions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          reaction.userName?.isNotEmpty == true
                              ? reaction.userName![0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(reaction.userName ?? 'Unknown User'),
                      subtitle: Text(reaction.postReaction?.label ?? ''),
                      trailing: Icon(
                        _getReactionIcon(reaction.postReaction?.label ?? ''),
                        color: Colors.amber,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getReactionIcon(String reactionType) {
    switch (reactionType.toLowerCase()) {
      case 'like':
        return Icons.thumb_up;
      case 'love':
        return Icons.favorite;
      case 'haha':
        return Icons.emoji_emotions;
      case 'wow':
        return Icons.emoji_events;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.thumb_up;
    }
  }
}