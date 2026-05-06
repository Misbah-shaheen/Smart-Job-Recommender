// screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';

import 'job_search_screen.dart';
import 'recommendation_screen.dart';
import 'skill_gap_screen.dart';
import 'trending_skills_screen.dart';
import 'notifications_screen.dart';
import 'career_insights_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';   // ← NEW

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _notifCount = 3;

  static const _titles = [
    'Job Search',
    'For You',
    'Skill Gap Analyser',
    'Trending Skills',
    'Career Insights',
    'Notifications',
    'My Profile',
    'AI Assistant',   // ← NEW (index 7)
    'Settings',       // ← moved to 8
  ];

  static const _navItems = [
    _NavItem(Icons.search_rounded,        'Job Search',      'Find your next role'),
    _NavItem(Icons.auto_awesome_rounded,  'For You',         'ML-powered matches'),
    _NavItem(Icons.analytics_rounded,     'Skill Gap',       'See what to learn'),
    _NavItem(Icons.trending_up_rounded,   'Trending Skills', 'In-demand skills'),
    _NavItem(Icons.insights_rounded,      'Career Insights', 'Growth & predictions'),
    _NavItem(Icons.notifications_rounded, 'Notifications',   'Alerts & updates'),
    _NavItem(Icons.person_rounded,        'Profile',         'Manage your info'),
    _NavItem(Icons.smart_toy_rounded,     'AI Assistant',    'Chat with AI career coach'), // ← NEW
    _NavItem(Icons.settings_rounded,      'Settings',        'App preferences'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifCount();
  }

  Future<void> _loadNotifCount() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) => k.startsWith('notif_read_'));
    final read  = keys.where((k) => prefs.getBool(k) == true).length;
    if (mounted) setState(() => _notifCount = (12 - read).clamp(0, 99));
  }

  void _selectItem(int i) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _selectedIndex = i);
        if (i == 5) _loadNotifCount();
      }
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:  return const JobSearchBody();
      case 1:  return const RecommendationBody();
      case 2:  return const SkillGapBody();
      case 3:  return const TrendingSkillsBody();
      case 4:  return const CareerInsightsBody();
      case 5:  return const NotificationsBody();
      case 6:  return const ProfileBody();
      case 7:  return const ChatbotBody();    // ← NEW
      case 8:  return const SettingsBody();   // ← moved
      default: return const JobSearchBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _titles[_selectedIndex],
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: _buildActions(),
      ),
      // ── FAB: quick-access to AI chatbot from any screen ───────────────
      floatingActionButton: _selectedIndex != 7
          ? FloatingActionButton(
        onPressed: () => setState(() => _selectedIndex = 7),
        backgroundColor: AppTheme.primary,
        tooltip: 'AI Career Assistant',
        child: const Icon(Icons.smart_toy_rounded,
            color: Colors.white),
      )
          : null,
      body: _buildBody(),
    );
  }

  List<Widget> _buildActions() {
    if (_selectedIndex == 1) {
      return [
        Consumer<AppProvider>(
          builder: (_, p, __) => IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: p.loadingRec ? null : () => p.fetchRecommendations(),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _buildDrawer() {
    final provider = context.watch<AppProvider>();
    final profile  = provider.profile;

    return Drawer(
      width: 288,
      backgroundColor: const Color(0xFF0D0D1A),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Text(
                      profile?.name.isNotEmpty == true
                          ? profile!.name[0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name.isNotEmpty == true
                              ? profile!.name
                              : 'Welcome!',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.user?.email ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Nav items ────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  final item    = _navItems[i];
                  final active  = i == _selectedIndex;
                  final isNotif = i == 5;
                  final isAI    = i == 7;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 2),
                    child: Material(
                      color: active
                          ? (isAI
                          ? AppTheme.primary.withOpacity(0.2)
                          : const Color(0xFF6C63FF).withOpacity(0.15))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectItem(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // AI icon gets gradient treatment
                                  isAI
                                      ? Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6C63FF),
                                          Color(0xFF48CAE4),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Icon(
                                    item.icon,
                                    size: 22,
                                    color: active
                                        ? const Color(0xFF6C63FF)
                                        : Colors.white54,
                                  ),
                                  if (isNotif && _notifCount > 0)
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF6B6B),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _notifCount > 9
                                                ? '9+'
                                                : '$_notifCount',
                                            style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? const Color(0xFF6C63FF)
                                            : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      item.subtitle,
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                              // NEW badge on AI item
                              if (isAI && !active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withOpacity(0.4)),
                                  ),
                                  child: Text('NEW',
                                      style: GoogleFonts.inter(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary)),
                                )
                              else if (active)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6C63FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // ── Sign out ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<AppProvider>().signOut();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            size: 20, color: Color(0xFFFF6B6B)),
                        const SizedBox(width: 16),
                        Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String subtitle;
  const _NavItem(this.icon, this.label, this.subtitle);
}