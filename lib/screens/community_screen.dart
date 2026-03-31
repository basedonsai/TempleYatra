import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _storyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF8B0000),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.feed, size: 20),
                    const SizedBox(width: 6),
                    Text(isSmallScreen ? '' : 'Feed'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 20),
                    const SizedBox(width: 6),
                    Text(isSmallScreen ? '' : 'Contribute'),
                  ],
                ),
              ),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _CommunityFeedTab(),
            _ContributeTab(
              formKey: _formKey,
              storyController: _storyController,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Recently Added Stories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        _StoryCard(
          title: 'The Miracle at Kashi',
          author: 'Rajesh Kumar',
          temple: 'Kashi Vishwanath',
          status: 'Published',
          isPublished: true,
        ),
        _StoryCard(
          title: 'My Journey to Tirupati',
          author: 'Priya Sharma',
          temple: 'Tirupati Balaji',
          status: 'Published',
          isPublished: true,
        ),
        _StoryCard(
          title: 'Ancient Legends of Somnath',
          author: 'Amit Patel',
          temple: 'Somnath Temple',
          status: 'Pending Review',
          isPublished: false,
        ),
        _StoryCard(
          title: 'Festival Memories',
          author: 'Sneha Reddy',
          temple: 'Meenakshi Temple',
          status: 'Published',
          isPublished: true,
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String title;
  final String author;
  final String temple;
  final String status;
  final bool isPublished;

  const _StoryCard({
    required this.title,
    required this.author,
    required this.temple,
    required this.status,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9933).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFFF9933),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        temple,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPublished 
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      color: isPublished ? Colors.green[700] : Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.thumb_up, size: 16, color: Colors.grey),
                  label: Text(
                    'Like',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.comment, size: 16, color: Colors.grey),
                  label: Text(
                    'Comment',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.share,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributeTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController storyController;

  const _ContributeTab({
    required this.formKey,
    required this.storyController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Your Temple Story',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contribute your temple experiences, stories, and insights to help others on their spiritual journey.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Story form
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Temple',
                    prefixIcon: Icon(Icons.temple_hindu),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Chilkur Balaji Temple',
                    'Jagannath Temple, Hyderabad',
                    'Srisailam Mallikarjuna Swamy Temple',
                    'Birla Mandir, Hyderabad',
                  ].map((temple) {
                    return DropdownMenuItem(
                      value: temple,
                      child: Text(temple),
                    );
                  }).toList(),
                  onChanged: (value) {},
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: storyController,
                  decoration: const InputDecoration(
                    labelText: 'Your Story',
                    hintText: 'Share your temple experience...',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please share your story';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Temple Visit',
                    'Festival Experience',
                    'Spiritual Journey',
                    'Local Traditions',
                  ].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {},
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Story submitted for review!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9933),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Guidelines
                Card(
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.lightbulb_outline, color: Color(0xFFFF9933)),
                            SizedBox(width: 8),
                            Text(
                              'Contribution Guidelines',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGuidelineItem('Share authentic personal experiences'),
                        _buildGuidelineItem('Be respectful and inclusive'),
                        _buildGuidelineItem('Include location and date details'),
                        _buildGuidelineItem('Add photos if possible'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
