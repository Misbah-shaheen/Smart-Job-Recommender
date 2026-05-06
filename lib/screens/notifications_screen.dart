// screens/notifications_screen.dart
// vii. Notifications / Alerts — alerts for new job postings, trending skills, recommendations.
// Uses SharedPreferences for local notification state. No FCM needed.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class NotificationsBody extends StatefulWidget {
  const NotificationsBody({super.key});

  @override
  State<NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<NotificationsBody>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  final List<_NotifItem> _notifications = [];
  bool _loaded = false;
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildNotifications());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _buildNotifications() async {
    final provider = context.read<AppProvider>();
    await provider.loadJobs();
    final jobs = provider.filteredJobs;
    final profile = provider.profile;
    final prefs = await SharedPreferences.getInstance();

    final List<_NotifItem> items = [];

    // New job alerts based on skills
    final userSkills = profile?.skills.map((s) => s.toLowerCase()).toSet() ?? {};
    if (userSkills.isNotEmpty) {
      final matched = jobs
          .where((j) => j.skills.any((s) => userSkills.contains(s.toLowerCase())))
          .take(5)
          .toList();
      for (int i = 0; i < matched.length; i++) {
        final job = matched[i];
        items.add(_NotifItem(
          id: 'job_${job.id}',
          type: _NotifType.newJob,
          title: 'New Match: ${job.jobTitle}',
          subtitle:
          'Matches ${job.skills.where((s) => userSkills.contains(s.toLowerCase())).length} of your skills • \$${(job.salary / 1000).toStringAsFixed(0)}k',
          time: _timeAgo(i),
          isRead: prefs.getBool('notif_read_job_${job.id}') ?? false,
          data: job,
        ));
      }
    } else {
      // No profile — show sample job alerts
      for (int i = 0; i < min(3, jobs.length); i++) {
        final job = jobs[i];
        items.add(_NotifItem(
          id: 'job_${job.id}',
          type: _NotifType.newJob,
          title: 'Featured: ${job.jobTitle}',
          subtitle: '${job.workType} • \$${(job.salary / 1000).toStringAsFixed(0)}k',
          time: _timeAgo(i),
          isRead: prefs.getBool('notif_read_job_${job.id}') ?? false,
          data: job,
        ));
      }
    }

    // Trending skill alerts
    final Map<String, int> skillCounts = {};
    for (final job in jobs) {
      for (final s in job.skills) {
        skillCounts[s] = (skillCounts[s] ?? 0) + 1;
      }
    }
    final topSkills = skillCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (int i = 0; i < min(3, topSkills.length); i++) {
      final skill = topSkills[i];
      items.add(_NotifItem(
        id: 'trend_${skill.key}',
        type: _NotifType.trendingSkill,
        title: '🔥 "${skill.key}" is trending',
        subtitle:
        'Demanded in ${skill.value} job listings this week. Add it to your profile!',
        time: _timeAgo(i + 3),
        isRead: prefs.getBool('notif_read_trend_${skill.key}') ?? false,
      ));
    }

    // Recommendation alert
    items.add(const _NotifItem(
      id: 'rec_1',
      type: _NotifType.recommendation,
      title: '✨ Your personalized picks are ready',
      subtitle: 'We found jobs tailored to your skills. Check the For You tab.',
      time: '2 days ago',
      isRead: false,
    ));

    // Career insight
    items.add(const _NotifItem(
      id: 'insight_1',
      type: _NotifType.insight,
      title: '📈 AI/ML roles growing 34% this quarter',
      subtitle: 'Python + Machine Learning skills are dominating new postings.',
      time: '3 days ago',
      isRead: true,
    ));

    // Sort by read state (unread first) then by time
    items.sort((a, b) => a.isRead == b.isRead ? 0 : (a.isRead ? 1 : -1));

    setState(() {
      _notifications.clear();
      _notifications.addAll(items);
      _loaded = true;
    });
    _fadeCtrl.forward();
  }

  String _timeAgo(int offsetHours) {
    if (offsetHours == 0) return 'Just now';
    if (offsetHours == 1) return '1 hour ago';
    if (offsetHours < 24) return '$offsetHours hours ago';
    return '${(offsetHours / 24).round()} days ago';
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> _markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_read_$id', true);
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
    });
  }

  Future<void> _markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    for (final n in _notifications) {
      await prefs.setBool('notif_read_${n.id}', true);
    }
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
  }

  List<_NotifItem> get _filtered {
    if (_activeFilter == 'All') return _notifications;
    final type = _NotifType.values.firstWhere(
          (t) => t.label == _activeFilter,
      orElse: () => _NotifType.newJob,
    );
    return _notifications.where((n) => n.type == type).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        if (!_loaded)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          SliverToBoxAdapter(child: _buildFilterBar()),
          _filtered.isEmpty
              ? SliverFillRemaining(child: _buildEmpty())
              : SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) => FadeTransition(
                opacity: _fadeCtrl,
                child: _NotifCard(
                  item: _filtered[i],
                  onTap: () => _markRead(_filtered[i].id),
                ),
              ),
              childCount: _filtered.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0D0D1A),
      elevation: 0,
      title: Row(
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_unreadCount',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.black.withOpacity(0.06),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', ..._NotifType.values.map((t) => t.label)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final f = filters[i];
            final active = _activeFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF6C63FF) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF6C63FF)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text('No notifications here',
              style: GoogleFonts.inter(color: Colors.black38, fontSize: 16)),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onTap;

  const _NotifCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? Colors.black.withOpacity(0.06)
                : const Color(0xFF6C63FF).withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.type.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.type.icon, color: item.type.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.time,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotifType {
  newJob,
  trendingSkill,
  recommendation,
  insight;

  String get label {
    switch (this) {
      case _NotifType.newJob:
        return 'Jobs';
      case _NotifType.trendingSkill:
        return 'Trending';
      case _NotifType.recommendation:
        return 'For You';
      case _NotifType.insight:
        return 'Insights';
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifType.newJob:
        return Icons.work_outline;
      case _NotifType.trendingSkill:
        return Icons.trending_up;
      case _NotifType.recommendation:
        return Icons.auto_awesome_outlined;
      case _NotifType.insight:
        return Icons.insights_outlined;
    }
  }

  Color get color {
    switch (this) {
      case _NotifType.newJob:
        return const Color(0xFF6C63FF);
      case _NotifType.trendingSkill:
        return const Color(0xFFFF6B6B);
      case _NotifType.recommendation:
        return const Color(0xFF48CAE4);
      case _NotifType.insight:
        return const Color(0xFF6BCB77);
    }
  }
}

class _NotifItem {
  final String id;
  final _NotifType type;
  final String title;
  final String subtitle;
  final String time;
  final bool isRead;
  final JobModel? data;

  const _NotifItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isRead,
    this.data,
  });

  _NotifItem copyWith({bool? isRead}) => _NotifItem(
    id: id,
    type: type,
    title: title,
    subtitle: subtitle,
    time: time,
    isRead: isRead ?? this.isRead,
    data: data,
  );
}

// Legacy alias
typedef NotificationsScreen = NotificationsBody;