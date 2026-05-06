// screens/trending_skills_screen.dart
// vi. Trending Skills Dashboard — top in-demand skills with animated charts.
// Data is derived locally from the bundled jobs.json — no backend needed.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class TrendingSkillsBody extends StatefulWidget {
  const TrendingSkillsBody({super.key});

  @override
  State<TrendingSkillsBody> createState() => _TrendingSkillsBodyState();
}

class _TrendingSkillsBodyState extends State<TrendingSkillsBody>
    with TickerProviderStateMixin {
  late AnimationController _barAnimCtrl;
  late AnimationController _headerAnimCtrl;
  late Animation<double> _barAnim;
  late Animation<double> _headerAnim;

  List<MapEntry<String, int>> _skillCounts = [];
  List<MapEntry<String, int>> _categoryCounts = [];
  String _selectedCategory = 'All';
  bool _loaded = false;

  final Map<String, List<String>> _categories = {
    'Cloud': ['aws', 'azure', 'gcp', 'kubernetes', 'docker', 'terraform'],
    'AI/ML': [
      'machine learning',
      'deep learning',
      'nlp',
      'tensorflow',
      'pytorch',
      'pandas',
      'numpy',
      'scikit-learn'
    ],
    'Web': [
      'javascript',
      'typescript',
      'react',
      'node.js',
      'html',
      'css',
      'next.js'
    ],
    'Data': [
      'sql',
      'postgresql',
      'mongodb',
      'spark',
      'kafka',
      'hadoop',
      'redis'
    ],
    'Mobile': ['flutter', 'dart', 'kotlin', 'swift', 'react native'],
    'Backend': ['python', 'java', 'go', 'rest api', 'graphql', 'linux'],
  };

  final List<Color> _barColors = [
    const Color(0xFF6C63FF),
    const Color(0xFF48CAE4),
    const Color(0xFFFF6B6B),
    const Color(0xFFFFD93D),
    const Color(0xFF6BCB77),
    const Color(0xFFFF922B),
    const Color(0xFFC084FC),
    const Color(0xFF34D399),
    const Color(0xFFF472B6),
    const Color(0xFF60A5FA),
  ];

  @override
  void initState() {
    super.initState();
    _barAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _barAnim = CurvedAnimation(parent: _barAnimCtrl, curve: Curves.easeOutCubic);
    _headerAnim = CurvedAnimation(parent: _headerAnimCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _barAnimCtrl.dispose();
    _headerAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    await provider.loadJobs();
    final jobs = provider.filteredJobs;
    _computeStats(jobs);
  }

  void _computeStats(List<JobModel> jobs) {
    final Map<String, int> counts = {};
    for (final job in jobs) {
      for (final skill in job.skills) {
        final s = skill.toLowerCase().trim();
        if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
      }
    }

    List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Category counts
    final Map<String, int> catCounts = {};
    for (final entry in _categories.entries) {
      int total = 0;
      for (final skill in entry.value) {
        total += counts[skill] ?? 0;
      }
      if (total > 0) catCounts[entry.key] = total;
    }
    final sortedCats = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _skillCounts = sorted;
      _categoryCounts = sortedCats;
      _loaded = true;
    });

    _headerAnimCtrl.forward();
    Future.delayed(
      const Duration(milliseconds: 200),
          () => _barAnimCtrl.forward(),
    );
  }

  List<MapEntry<String, int>> get _filteredSkills {
    if (_selectedCategory == 'All') return _skillCounts.take(12).toList();
    final catSkills = _categories[_selectedCategory] ?? [];
    return _skillCounts
        .where((e) => catSkills.contains(e.key))
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        if (!_loaded)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _buildStatsRow()),
          SliverToBoxAdapter(child: _buildCategoryFilter()),
          SliverToBoxAdapter(child: _buildBarChart()),
          SliverToBoxAdapter(child: _buildSkillGrid()),
          SliverToBoxAdapter(child: _buildCategoryBreakdown()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A3E), Color(0xFF0D0D1A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: 80,
              bottom: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF48CAE4).withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Trending Skills',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time demand from ${_skillCounts.fold(0, (s, e) => s + e.value)} job postings',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white38,
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

  Widget _buildStatsRow() {
    final top = _skillCounts.isNotEmpty ? _skillCounts.first : null;
    final totalSkills = _skillCounts.length;
    final hotSkills = _skillCounts.where((e) => e.value >= 3).length;

    return FadeTransition(
      opacity: _headerAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            _StatCard(
              label: 'Unique Skills',
              value: '$totalSkills',
              icon: Icons.bubble_chart_outlined,
              color: const Color(0xFF6C63FF),
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Hot Skills',
              value: '$hotSkills',
              icon: Icons.local_fire_department,
              color: const Color(0xFFFF6B6B),
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: '#1 Skill',
              value: top?.key.toUpperCase() ?? '—',
              icon: Icons.emoji_events,
              color: const Color(0xFFFFD93D),
              small: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final cats = ['All', ..._categories.keys];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTER BY CATEGORY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white30,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = cats[i];
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _barAnimCtrl.reset();
                    _barAnimCtrl.forward();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                      )
                          : null,
                      color: selected ? null : const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final skills = _filteredSkills;
    if (skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No skills in this category yet',
            style: GoogleFonts.inter(color: Colors.white38),
          ),
        ),
      );
    }
    final maxVal = skills.first.value.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEMAND OVERVIEW',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white30,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF13132B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: AnimatedBuilder(
              animation: _barAnim,
              builder: (context, _) {
                return Column(
                  children: skills.asMap().entries.map((entry) {
                    final i = entry.key;
                    final skill = entry.value;
                    final pct = skill.value / maxVal;
                    final color = _barColors[i % _barColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              skill.key,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: pct * _barAnim.value,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [color, color.withOpacity(0.6)],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${skill.value}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP SKILLS HEATMAP',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white30,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillCounts.take(20).toList().asMap().entries.map((e) {
              final i = e.key;
              final skill = e.value;
              final maxV = _skillCounts.first.value;
              final heat = skill.value / maxV;
              final color = _barColors[i % _barColors.length];
              final size = 12.0 + heat * 6;
              return AnimatedBuilder(
                animation: _barAnim,
                builder: (context, _) => Opacity(
                  opacity: _barAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08 + heat * 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.withOpacity(0.3 + heat * 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            skill.key,
                            style: GoogleFonts.inter(
                              fontSize: size,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${skill.value}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryCounts.isEmpty) return const SizedBox();
    final maxV = _categoryCounts.first.value.toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY DEMAND',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.white30,
            ),
          ),
          const SizedBox(height: 14),
          ..._categoryCounts.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            final pct = cat.value / maxV;
            final color = _barColors[i % _barColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13132B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_categoryIcon(cat.key),
                            color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat.key,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${cat.value} jobs',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: pct * _barAnim.value,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [color, color.withOpacity(0.5)],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
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
          }),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Cloud':
        return Icons.cloud_outlined;
      case 'AI/ML':
        return Icons.psychology_outlined;
      case 'Web':
        return Icons.web_outlined;
      case 'Data':
        return Icons.storage_outlined;
      case 'Mobile':
        return Icons.smartphone_outlined;
      case 'Backend':
        return Icons.code_outlined;
      default:
        return Icons.stars_outlined;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool small;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF13132B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: small ? 13 : 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Legacy alias
typedef TrendingSkillsScreen = TrendingSkillsBody;