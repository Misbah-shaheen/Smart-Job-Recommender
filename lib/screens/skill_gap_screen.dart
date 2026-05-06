// screens/skill_gap_screen.dart
//
// PERFORMANCE FIX: The original DropdownButton built ALL 25,000 job items
// as widgets at once → Flutter froze / crashed.
// Replaced with a _JobSearchSheet that:
//   • Only renders 60 visible items at a time (ListView.builder)
//   • Filters the list as the user types (client-side, instant)
//   • Never mounts more than ~60 widgets regardless of dataset size

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class SkillGapBody extends StatefulWidget {
  const SkillGapBody({super.key});

  @override
  State<SkillGapBody> createState() => _SkillGapBodyState();
}

class _SkillGapBodyState extends State<SkillGapBody> {
  JobModel? _selectedJob;
  List<String> _matching = [];
  List<String> _missing  = [];
  Map<String, int> _demandMap = {};
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AppProvider>().loadJobsIfNeeded();
      // getSkillDemandMap() is now cached inside JobService — safe to call
      final map = await context.read<AppProvider>().getSkillDemandMap();
      if (mounted) setState(() => _demandMap = map);
    });
  }

  Future<void> _analyze() async {
    if (_selectedJob == null) return;
    setState(() { _loading = true; _error = null; _matching = []; _missing = []; });
    try {
      final result =
      await context.read<AppProvider>().fetchSkillGap(_selectedJob!.id);
      setState(() {
        _matching = List<String>.from(result['matching'] as List? ?? []);
        _missing  = List<String>.from(result['missing']  as List? ?? []);
      });
    } catch (e) {
      setState(() => _error = 'Analysis failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Job picker ────────────────────────────────────────────────────────
  // Opens a bottom sheet with a search field + virtualized list.
  // Only ~60 items are ever rendered at once regardless of dataset size.
  Future<void> _openJobPicker(List<JobModel> jobs) async {
    final picked = await showModalBottomSheet<JobModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _JobSearchSheet(jobs: jobs),
    );
    if (picked != null) {
      setState(() {
        _selectedJob = picked;
        _matching = [];
        _missing  = [];
        _error    = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final jobs    = provider.filteredJobs;
        final profile = provider.profile;

        if (profile == null || profile.skills.isEmpty) {
          return const _EmptyProfilePrompt();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Your skills ─────────────────────────────────────────
              const _SectionTitle('Your Skills'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: profile.skills
                    .map((s) => _SkillChip(label: s, type: ChipType.neutral))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // ── Job selector ─────────────────────────────────────────
              const _SectionTitle('Select a Job to Analyse'),
              const SizedBox(height: 8),

              // FIX: tap to open the virtualized search sheet instead of
              // a DropdownButton that mounts 25,000 widgets simultaneously.
              GestureDetector(
                onTap: () => _openJobPicker(jobs),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E3A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedJob != null
                              ? '${_selectedJob!.jobTitle} · ${_selectedJob!.company}'
                              : 'Choose a job role…',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _selectedJob != null
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.search, color: Colors.white54, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Analyse button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedJob == null || _loading) ? null : _analyze,
                  icon: _loading
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.analytics_outlined),
                  label: Text(_loading ? 'Analysing…' : 'Analyse Skill Gap'),
                ),
              ),

              // ── Error ────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppTheme.error)),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Results ──────────────────────────────────────────────
              if (_matching.isNotEmpty || _missing.isNotEmpty) ...[
                const SizedBox(height: 28),
                _GapResultsCard(
                  jobTitle: _selectedJob!.jobTitle,
                  company:  _selectedJob!.company,
                  matching: _matching,
                  missing:  _missing,
                  demandMap: _demandMap,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Virtualized job search bottom sheet ──────────────────────────────────────
// Renders only visible items — safe for 25,000+ jobs.
class _JobSearchSheet extends StatefulWidget {
  final List<JobModel> jobs;
  const _JobSearchSheet({required this.jobs});

  @override
  State<_JobSearchSheet> createState() => _JobSearchSheetState();
}

class _JobSearchSheetState extends State<_JobSearchSheet> {
  late List<JobModel> _visible;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Show first 500 immediately; user narrows with search
    _visible = widget.jobs.take(500).toList();
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase().trim();
    if (lower.isEmpty) {
      setState(() => _visible = widget.jobs.take(500).toList());
    } else {
      // Filter on background-safe synchronous string ops — fast enough
      // because this only runs after the user types (debounced by Flutter's
      // onChange cadence) and returns early once 200 results are found.
      final results = <JobModel>[];
      for (final job in widget.jobs) {
        if (job.jobTitle.toLowerCase().contains(lower) ||
            job.company.toLowerCase().contains(lower)) {
          results.add(job);
          if (results.length >= 200) break;
        }
      }
      setState(() => _visible = results);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search job title or company…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_visible.length} result${_visible.length == 1 ? '' : 's'}'
                      '${_visible.length >= 200 ? ' (showing first 200)' : ''}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Virtualized list — only visible items are mounted
          Expanded(
            child: ListView.builder(
              itemCount: _visible.length,
              itemExtent: 64, // fixed height enables smarter recycling
              itemBuilder: (_, i) {
                final job = _visible[i];
                return ListTile(
                  title: Text(
                    job.jobTitle,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    job.company,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, job),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Results card ─────────────────────────────────────────────────────────────
class _GapResultsCard extends StatelessWidget {
  final String jobTitle, company;
  final List<String> matching, missing;
  final Map<String, int> demandMap;

  const _GapResultsCard({
    required this.jobTitle,
    required this.company,
    required this.matching,
    required this.missing,
    required this.demandMap,
  });

  @override
  Widget build(BuildContext context) {
    final total = matching.length + missing.length;
    final pct   = total == 0 ? 0.0 : matching.length / total;

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 350),
          childAnimationBuilder: (w) => SlideAnimation(
              verticalOffset: 20, child: FadeInAnimation(child: w)),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E3A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobTitle,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(company,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.primary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatBox(value: '${matching.length}', label: 'Matched',
                          color: AppTheme.success,
                          icon: Icons.check_circle_outline),
                      const SizedBox(width: 10),
                      _StatBox(value: '${missing.length}', label: 'Missing',
                          color: AppTheme.error, icon: Icons.cancel_outlined),
                      const SizedBox(width: 10),
                      _StatBox(
                          value: '${(pct * 100).toStringAsFixed(0)}%',
                          label: 'Ready',
                          color: AppTheme.primary,
                          icon: Icons.auto_graph),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppTheme.error.withOpacity(0.2),
                      valueColor:
                      const AlwaysStoppedAnimation(AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Matched skills
            if (matching.isNotEmpty) ...[
              const _SectionTitle('✅  Skills You Already Have'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: matching
                    .map((s) => _SkillChip(label: s, type: ChipType.matching))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Missing skills
            if (missing.isNotEmpty) ...[
              Row(
                children: [
                  const Expanded(child: _SectionTitle('📚  Skills to Learn')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Sorted by demand',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Learn the top skill first — it appears in the most job listings.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: missing.asMap().entries.map((entry) {
                  final demand =
                      demandMap[entry.value.toLowerCase().trim()] ?? 0;
                  return _MissingSkillChip(
                    label: entry.value,
                    demandCount: demand,
                    priority: entry.key,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Learning path
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Recommended Learning Path',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...missing.take(3).toList().asMap().entries.map((e) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text('${e.key + 1}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _tip(e.value,
                                      demandMap[e.value.toLowerCase()] ?? 0),
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (missing.length > 3)
                      Text(
                        '+ ${missing.length - 3} more skills to learn.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tip(String skill, int demand) {
    if (demand >= 10) return '$skill — very high demand ($demand jobs). Learn this first.';
    if (demand >= 4)  return '$skill — high demand ($demand jobs). Good ROI.';
    if (demand >= 2)  return '$skill — needed in $demand jobs.';
    return '$skill — required for this specific role.';
  }
}

// ─── Chip widgets ─────────────────────────────────────────────────────────────
class _MissingSkillChip extends StatelessWidget {
  final String label;
  final int demandCount, priority;
  const _MissingSkillChip(
      {required this.label,
        required this.demandCount,
        required this.priority});

  @override
  Widget build(BuildContext context) {
    final isTop = priority == 0;
    final color = isTop ? AppTheme.warning : AppTheme.error;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withOpacity(isTop ? 0.6 : 0.3),
            width: isTop ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTop ? Icons.star : Icons.add_circle_outline,
              size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                    color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
          if (demandCount > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$demandCount',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ],
      ),
    );
  }
}

enum ChipType { matching, missing, neutral }

class _SkillChip extends StatelessWidget {
  final String label;
  final ChipType type;
  const _SkillChip({required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == ChipType.matching
        ? AppTheme.success
        : type == ChipType.missing
        ? AppTheme.error
        : AppTheme.primary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == ChipType.matching
                ? Icons.check_circle
                : type == ChipType.missing
                ? Icons.add_circle_outline
                : Icons.circle,
            size: 13, color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatBox(
      {required this.value,
        required this.label,
        required this.color,
        required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary));
}

class _EmptyProfilePrompt extends StatelessWidget {
  const _EmptyProfilePrompt();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined,
              size: 64, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Add your skills first',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Go to Profile and add your skills to start analysing skill gaps.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}

typedef SkillGapScreen = SkillGapBody;