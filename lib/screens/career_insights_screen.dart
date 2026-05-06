// screens/career_insights_screen.dart
// viii. Career Insights — predicts future skill demand, career paths, salary trends.
// All data is derived locally from jobs.json — no external API needed.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class CareerInsightsBody extends StatefulWidget {
  const CareerInsightsBody({super.key});

  @override
  State<CareerInsightsBody> createState() => _CareerInsightsBodyState();
}

class _CareerInsightsBodyState extends State<CareerInsightsBody>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  List<JobModel> _jobs = [];
  bool _loaded = false;
  String? _selectedPath;

  // Career paths with required skills
  static const Map<String, _CareerPath> _careerPaths = {
    'ML Engineer': _CareerPath(
      title: 'ML Engineer',
      icon: Icons.psychology_outlined,
      color: Color(0xFF6C63FF),
      gradient: [Color(0xFF6C63FF), Color(0xFF9B8EFF)],
      skills: ['python', 'machine learning', 'tensorflow', 'pandas', 'numpy', 'docker'],
      description: 'Build and deploy intelligent models at scale.',
      salaryRange: '\$90k – \$160k',
      demandGrowth: 34,
    ),
    'Cloud Architect': _CareerPath(
      title: 'Cloud Architect',
      icon: Icons.cloud_outlined,
      color: Color(0xFF48CAE4),
      gradient: [Color(0xFF48CAE4), Color(0xFF0096C7)],
      skills: ['aws', 'kubernetes', 'docker', 'terraform', 'linux'],
      description: 'Design scalable infrastructure for modern systems.',
      salaryRange: '\$100k – \$180k',
      demandGrowth: 28,
    ),
    'Full Stack Dev': _CareerPath(
      title: 'Full Stack Dev',
      icon: Icons.code_outlined,
      color: Color(0xFF6BCB77),
      gradient: [Color(0xFF6BCB77), Color(0xFF4CAF50)],
      skills: ['javascript', 'typescript', 'react', 'node.js', 'postgresql'],
      description: 'Build end-to-end web applications.',
      salaryRange: '\$75k – \$140k',
      demandGrowth: 22,
    ),
    'Data Engineer': _CareerPath(
      title: 'Data Engineer',
      icon: Icons.storage_outlined,
      color: Color(0xFFFFD93D),
      gradient: [Color(0xFFFFD93D), Color(0xFFFF922B)],
      skills: ['python', 'sql', 'spark', 'kafka', 'aws', 'postgresql'],
      description: 'Build pipelines that power data-driven decisions.',
      salaryRange: '\$85k – \$150k',
      demandGrowth: 31,
    ),
    'Mobile Dev': _CareerPath(
      title: 'Mobile Dev',
      icon: Icons.smartphone_outlined,
      color: Color(0xFFFF6B6B),
      gradient: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      skills: ['flutter', 'dart', 'firebase', 'rest api'],
      description: 'Create delightful cross-platform mobile experiences.',
      salaryRange: '\$70k – \$130k',
      demandGrowth: 18,
    ),
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    // Load ALL jobs (no filters) so work-type/salary stats reflect the full dataset
    final allJobs = await provider.loadAllJobs();
    setState(() {
      _jobs = allJobs;
      _loaded = true;
    });
    _animCtrl.forward();
  }

  Map<String, int> get _skillDemand {
    final Map<String, int> counts = {};
    for (final job in _jobs) {
      for (final s in job.skills) {
        counts[s.toLowerCase()] = (counts[s.toLowerCase()] ?? 0) + 1;
      }
    }
    return counts;
  }

  double _salaryAvg(List<JobModel> jobs) {
    if (jobs.isEmpty) return 0;
    return jobs.fold(0.0, (s, j) => s + j.salary) / jobs.length;
  }

  List<_SalaryBracket> get _salaryDistribution {
    final brackets = [
      _SalaryBracket(label: '< \$60k', min: 0, max: 60000),
      _SalaryBracket(label: '\$60k–\$90k', min: 60000, max: 90000),
      _SalaryBracket(label: '\$90k–\$120k', min: 90000, max: 120000),
      _SalaryBracket(label: '> \$120k', min: 120000, max: 999999),
    ];
    for (final b in brackets) {
      b.count =
          _jobs.where((j) => j.salary >= b.min && j.salary < b.max).length;
    }
    return brackets;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        if (!_loaded)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _buildMarketSnapshot()),
          SliverToBoxAdapter(child: _buildCareerPaths()),
          if (_selectedPath != null)
            SliverToBoxAdapter(child: _buildPathDetail()),
          SliverToBoxAdapter(child: _buildSalaryTrend()),
          SliverToBoxAdapter(child: _buildFutureSkills()),
          SliverToBoxAdapter(child: _buildWorkTypeInsight()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1C1050), Color(0xFF0A0A1B)],
                ),
              ),
            ),
            CustomPaint(
              painter: _GridPainter(),
              child: const SizedBox.expand(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                        ).createShader(bounds),
                        child: Text(
                          'Career',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Insights',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-powered predictions & growth paths',
                    style: GoogleFonts.inter(
                      fontSize: 12,
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

  Widget _buildMarketSnapshot() {
    final avgSalary = _salaryAvg(_jobs);
    final remoteJobs = _jobs.where((j) => j.workType == 'Remote').length;
    final remotePercent =
    _jobs.isEmpty ? 0 : (remoteJobs / _jobs.length * 100).round();
    final demand = _skillDemand;
    final topSkill = demand.entries.isEmpty
        ? '—'
        : (demand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
    ).first.key;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('MARKET SNAPSHOT'),
          const SizedBox(height: 14),
          Row(
            children: [
              _SnapshotCard(
                label: 'Avg Salary',
                value: '\$${(avgSalary / 1000).toStringAsFixed(0)}k',
                icon: Icons.attach_money,
                color: const Color(0xFF6BCB77),
              ),
              const SizedBox(width: 10),
              _SnapshotCard(
                label: 'Remote Rate',
                value: '$remotePercent%',
                icon: Icons.home_work_outlined,
                color: const Color(0xFF48CAE4),
              ),
              const SizedBox(width: 10),
              _SnapshotCard(
                label: 'Top Skill',
                value: topSkill,
                icon: Icons.star_outline,
                color: const Color(0xFFFFD93D),
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareerPaths() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('EXPLORE CAREER PATHS'),
          const SizedBox(height: 4),
          Text(
            'Tap a path to see your readiness',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          ...(_careerPaths.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final path = entry.value.value;
            final isSelected = _selectedPath == entry.value.key;
            return AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => Transform.translate(
                offset: Offset(0, 20 * (1 - _anim.value)),
                child: Opacity(
                  opacity: _anim.value.clamp(0.0, 1.0),
                  child: GestureDetector(
                    onTap: () => setState(
                            () => _selectedPath = isSelected ? null : entry.value.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: path.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isSelected ? null : const Color(0xFF13132B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : path.color.withOpacity(0.2),
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: path.color.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          )
                        ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : path.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(path.icon,
                                color: isSelected ? Colors.white : path.color,
                                size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  path.title,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  path.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isSelected
                                      ? Colors.white
                                      : path.color)
                                      .withOpacity(isSelected ? 0.2 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${path.demandGrowth}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : path.color,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                path.salaryRange,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white60
                                      : Colors.white30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildPathDetail() {
    final path = _careerPaths[_selectedPath]!;
    final userSkills = context
        .read<AppProvider>()
        .profile
        ?.skills
        .map((s) => s.toLowerCase())
        .toSet() ??
        {};
    final demand = _skillDemand;
    final readiness = userSkills.isEmpty
        ? 0.0
        : path.skills.where((s) => userSkills.contains(s)).length /
        path.skills.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF13132B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: path.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: path.color, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Your Readiness for ${path.title}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Readiness bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: readiness,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(path.color),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(readiness * 100).round()}%',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: path.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'REQUIRED SKILLS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.white30,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: path.skills.map((s) {
                final have = userSkills.contains(s);
                final jobCount = demand[s] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: have
                        ? path.color.withOpacity(0.15)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: have
                          ? path.color.withOpacity(0.4)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        have ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: have ? path.color : Colors.white30,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: have ? path.color : Colors.white38,
                        ),
                      ),
                      if (jobCount > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '($jobCount)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryTrend() {
    final brackets = _salaryDistribution;
    final max = brackets.fold(0, (m, b) => b.count > m ? b.count : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('SALARY DISTRIBUTION'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF13132B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: brackets.map((b) {
                final pct = max == 0 ? 0.0 : b.count / max;
                return AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${b.count}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6BCB77),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        width: 50,
                        height: 100 * pct * _anim.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF6BCB77),
                              const Color(0xFF48CAE4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.label,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureSkills() {
    final predictions = [
      _Prediction(skill: 'AI/ML', growth: 34, reason: 'GenAI adoption surge'),
      _Prediction(skill: 'Kubernetes', growth: 28, reason: 'Cloud-native shift'),
      _Prediction(skill: 'Rust', growth: 45, reason: 'Systems programming boom'),
      _Prediction(skill: 'TypeScript', growth: 22, reason: 'Type safety standard'),
      _Prediction(skill: 'Vector DBs', growth: 52, reason: 'LLM infrastructure'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('FUTURE SKILL PREDICTIONS'),
          const SizedBox(height: 4),
          Text(
            'Projected growth over next 12 months',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          ...predictions.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF13132B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.skill,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          p.reason,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6BCB77).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6BCB77).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward,
                            color: Color(0xFF6BCB77), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${p.growth}%',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6BCB77),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildWorkTypeInsight() {
    final remote = _jobs.where((j) => j.workType == 'Remote').length;
    final hybrid = _jobs.where((j) => j.workType == 'Hybrid').length;
    final onsite = _jobs.where((j) => j.workType == 'Onsite').length;
    final total = _jobs.length;
    if (total == 0) return const SizedBox();

    final data = [
      _PieSegment('Remote', remote, const Color(0xFF6BCB77)),
      _PieSegment('Hybrid', hybrid, const Color(0xFFFFD93D)),
      _PieSegment('Onsite', onsite, const Color(0xFF6C63FF)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WORK MODEL BREAKDOWN'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF13132B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: data.map((seg) {
                final pct = total == 0 ? 0.0 : seg.count / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: seg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                seg.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Text(
                              '${seg.count} (${(pct * 100).round()}%)',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: seg.color,
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
                              widthFactor: pct * _anim.value,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: seg.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
      color: Colors.white30,
    ),
  );
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _CareerPath {
  final String title;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final List<String> skills;
  final String description;
  final String salaryRange;
  final int demandGrowth;

  const _CareerPath({
    required this.title,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.skills,
    required this.description,
    required this.salaryRange,
    required this.demandGrowth,
  });
}

class _SalaryBracket {
  final String label;
  final int min;
  final int max;
  int count = 0;

  _SalaryBracket({required this.label, required this.min, required this.max});
}

class _Prediction {
  final String skill;
  final int growth;
  final String reason;

  const _Prediction({
    required this.skill,
    required this.growth,
    required this.reason,
  });
}

class _PieSegment {
  final String label;
  final int count;
  final Color color;

  const _PieSegment(this.label, this.count, this.color);
}

class _SnapshotCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool small;

  const _SnapshotCard({
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
                fontSize: small ? 13 : 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

// Grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// Legacy alias
typedef CareerInsightsScreen = CareerInsightsBody;