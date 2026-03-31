import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../models/temple_model.dart';
import 'yatra_planner_screen.dart';
import 'temple_detail_screen.dart';
import 'community_screen.dart';
import 'offline_pack_manager_screen.dart';
import '../data/temples_data.dart';
import 'temple_list_screen.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TempleListScreen(),
        ),
      );
    }
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWebDesktop = AppTheme.isWebDesktop(context);
    final isWebTablet = AppTheme.isWebTablet(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    // Responsive calculations
    final maxWidth = AppTheme.getMaxWidth(context);
    final horizontalPadding = isWebDesktop ? 24.0 : (isWebTablet ? 20.0 : 16.0);
    final gridCrossCount = isWebDesktop ? 4 : (isWebTablet ? 3 : 2);
    final gridChildAspectRatio = isWebDesktop ? 1.2 : (isWebTablet ? 1.3 : 1.4);
    final featuredCardWidth = isWebDesktop ? 280.0 : (isWebTablet ? 220.0 : (isSmallScreen ? 150.0 : 170.0));
    final iconSize = isSmallScreen ? 28.0 : (isWebDesktop ? 36.0 : 32.0);

    return Scaffold(
      backgroundColor: kIsWeb ? AppTheme.webBackground : AppTheme.lightBeige,
      body: SafeArea(
        child: Column(
          children: [
            // Web Header (desktop only)
            if (isWebDesktop) _buildWebHeader(),
            
            // App Bar for mobile/tablet
            if (!isWebDesktop)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.maroon, AppTheme.deepMaroon],
                  ),
                ),
                child: AppBar(
                  title: const Text('TempleYatra', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      onPressed: _openChatbot,
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      tooltip: 'Ask AI',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isWebDesktop ? 24.0 : 16.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        _buildWelcomeSection(isSmallScreen),
                        SizedBox(height: isWebDesktop ? 32.0 : 24.0),
                        
                        // Search Bar
                        _buildSearchBar(isSmallScreen),
                        SizedBox(height: isWebDesktop ? 40.0 : 24.0),
                        
                        // Quick Actions
                        _buildQuickActionsSection(
                          isSmallScreen,
                          isWebTablet,
                          gridCrossCount,
                          gridChildAspectRatio,
                          iconSize,
                        ),
                        SizedBox(height: isWebDesktop ? 48.0 : 24.0),
                        
                        // Featured Yatras
                        _buildFeaturedSection(
                          isSmallScreen,
                          isWebDesktop,
                          featuredCardWidth,
                        ),
                        SizedBox(height: isWebDesktop ? 48.0 : 24.0),
                        
                        // Upcoming Festivals
                        _buildFestivalsSection(isSmallScreen),
                        SizedBox(height: isWebDesktop ? 48.0 : 24.0),
                        
                        // Quick Stats (web only)
                        if (isWebDesktop) _buildQuickStats(),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Web Footer (desktop only)
            if (isWebDesktop) _buildWebFooter(),
          ],
        ),
      ),
      bottomNavigationBar: kIsWeb
          ? null
          : NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) {
                if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()),
                  );
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home, size: 26),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.explore, size: 26),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people, size: 26),
                  label: 'Community',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person, size: 26),
                  label: 'Profile',
                ),
              ],
              indicatorColor: AppTheme.saffron.withValues(alpha: 0.2),
            ),
      // Floating Action Button for mobile/tablet
      floatingActionButton: kIsWeb
          ? null
          : Container(
              margin: const EdgeInsets.only(right: 16, bottom: 16),
              child: FloatingActionButton.extended(
                onPressed: _openChatbot,
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome, size: 22),
                label: const Text('Ask AI', style: TextStyle(fontSize: 14)),
                extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
    );
  }

  Widget _buildWebHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.maroon,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.temple_hindu, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            const Text(
              'TempleYatra',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            _buildNavLink('Home', true),
            _buildNavLink('Explore', false),
            _buildNavLink('Plan Yatra', false),
            _buildNavLink('Community', false),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _openChatbot,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('Ask AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavLink(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: isActive ? AppTheme.saffron : Colors.white70,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to TempleYatra',
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Discover temples, plan your spiritual journey, and explore rich cultural heritage',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search temples, festivals, or destinations...',
          prefixIcon: Container(
            padding: const EdgeInsets.all(14),
            child: const Icon(Icons.search, color: AppTheme.saffron),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.cardBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        onSubmitted: _handleSearch,
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(
    bool isSmallScreen,
    bool isWebTablet,
    int gridCrossCount,
    double gridChildAspectRatio,
    double iconSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        GridView.count(
          crossAxisCount: gridCrossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: gridChildAspectRatio,
          children: [
            _QuickActionCard(
              icon: Icons.route,
              title: 'Plan Yatra',
              subtitle: 'Create your itinerary',
              color: AppTheme.saffron,
              iconSize: iconSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YatraPlannerScreen()),
                );
              },
            ),
            _QuickActionCard(
              icon: Icons.inventory_2,
              title: 'Temple Packs',
              subtitle: 'Offline content',
              color: AppTheme.templeGold,
              iconSize: iconSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfflinePackManagerScreen()),
                );
              },
            ),
            _QuickActionCard(
              icon: Icons.location_on,
              title: 'Nearby Temples',
              subtitle: 'Find temples nearby',
              color: AppTheme.maroon,
              iconSize: iconSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TempleListScreen()),
                );
              },
            ),
            _QuickActionCard(
              icon: Icons.celebration,
              title: 'Festivals',
              subtitle: 'Upcoming events',
              color: const Color(0xFFE91E63),
              iconSize: iconSize,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(
    bool isSmallScreen,
    bool isWebDesktop,
    double featuredCardWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Yatras',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          height: isWebDesktop ? 280.0 : (isSmallScreen ? 160.0 : 200.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allTemples.length,
            itemBuilder: (context, index) {
              final temple = allTemples[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _FeaturedCard(
                  width: featuredCardWidth,
                  temple: temple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TempleDetailScreen(temple: temple),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFestivalsSection(bool isSmallScreen) {
    final festivals = [
      {'name': 'Maha Shivaratri', 'date': 'March 8, 2024', 'color': AppTheme.maroon},
      {'name': 'Navaratri', 'date': 'October 15, 2024', 'color': AppTheme.saffron},
      {'name': 'Diwali', 'date': 'November 1, 2024', 'color': AppTheme.templeGold},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Festivals',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: festivals.length,
          itemBuilder: (context, index) {
            final festival = festivals[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FestivalCard(
                name: festival['name'] as String,
                date: festival['date'] as String,
                color: festival['color'] as Color,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(Icons.temple_hindu, '50+', 'Temples'),
          _buildStatItem(Icons.celebration, '20+', 'Festivals'),
          _buildStatItem(Icons.people, '10K+', 'Devotees'),
          _buildStatItem(Icons.rate_review, '4.8', 'Rating'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.saffron, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWebFooter() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.maroon,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.temple_hindu, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'TempleYatra',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your spiritual journey companion',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildFooterLink('About'),
            _buildFooterLink('Privacy'),
            _buildFooterLink('Terms'),
            _buildFooterLink('Contact'),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: () {},
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double iconSize;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: kIsWeb ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      color: AppTheme.cardBackground,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize + 12,
                height: iconSize + 12,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: iconSize,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final double width;
  final Temple temple;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.width,
    required this.temple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: kIsWeb ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        color: AppTheme.cardBackground,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.saffron.withValues(alpha: 0.85),
                      AppTheme.saffron,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.temple_hindu,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (temple.rating != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[400],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                temple.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temple.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            temple.address.split(',').take(2).join(','),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  final String name;
  final String date;
  final Color color;

  const _FestivalCard({
    required this.name,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: kIsWeb ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.celebration,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
