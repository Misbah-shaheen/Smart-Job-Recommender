// screens/recommendation_screen.dart
// Fixed:
//  1. Skills bar no longer cluttered — shows chips in a neat scrollable
//     horizontal row with a "+ N more" overflow chip instead of spilling.
//  2. Salary display updated for salary_min / salary_max.
//  3. Consistent dark theme throughout.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class RecommendationBody extends StatefulWidget {
  const RecommendationBody({super.key});
  @override
  State<RecommendationBody> createState() => _RecommendationBodyState();
}

class _RecommendationBodyState extends State<RecommendationBody> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;

        if (profile == null || profile.skills.isEmpty) {
          return const _NoProfileBanner();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Skills summary bar (fixed — no longer cluttered) ──
            _SkillsSummaryBar(skills: profile.skills),

            Expanded(
              child: provider.loadingRec
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text(
                      'Finding your best matches…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
                  : provider.error != null
                  ? _ErrorView(
                message: provider.error!,
                onRetry: provider.fetchRecommendations,
              )
                  : provider.recommendations.isEmpty
                  ? _EmptyView(onLoad: provider.fetchRecommendations)
                  : _RecommendationList(
                jobs: provider.recommendations,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Skills Summary Bar ────────────────────────────────────────────────────────
// FIX: previously used Wrap which made all chips pile up vertically and push
// content down. Now uses a single horizontal scrollable row, with a "+N more"
// chip when count > 5. This keeps the bar compact regardless of skill count.
class _SkillsSummaryBar extends StatelessWidget {
  final List<String> skills;
  const _SkillsSummaryBar({required this.skills});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 5;
    final visible = skills.take(maxVisible).toList();
    final overflow = skills.length - maxVisible;

    return Container(
      color: const Color(0xFF1A1A35),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Label
          Text(
            'Based on:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 10),

          // Horizontally scrollable skill chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visible.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )),
                  if (overflow > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$overflow more',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recommendation List ───────────────────────────────────────────────────────
class _RecommendationList extends StatelessWidget {
  final List<JobModel> jobs;
  const _RecommendationList({required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            'Top ${jobs.length} matches for you',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: jobs.length,
              itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 30,
                  child: FadeInAnimation(
                    child: _RecommendationCard(job: jobs[i], rank: i + 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Recommendation Card ───────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final JobModel job;
  final int rank;
  const _RecommendationCard({required this.job, required this.rank});

  @override
  Widget build(BuildContext context) {
    final pct = job.matchPercentage ?? 0;
    final color = pct >= 70
        ? AppTheme.success
        : pct >= 40
        ? AppTheme.warning
        : AppTheme.error;

    // Salary display: show range when min != max
    final salaryLabel = job.salaryMin == job.salaryMax
        ? '\$${(job.salaryMin / 1000).toStringAsFixed(0)}k'
        : '\$${(job.salaryMin / 1000).toStringAsFixed(0)}k–'
        '\$${(job.salaryMax / 1000).toStringAsFixed(0)}k';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.jobTitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Company + location row
                    Text(
                      job.company.isNotEmpty ? job.company : job.workType,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.work_outline,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          job.workType,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.attach_money,
                            size: 12, color: AppTheme.textSecondary),
                        Text(
                          salaryLabel,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Match % badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Match score bar
          Text(
            'Match Score',
            style: GoogleFonts.inter(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          LinearPercentIndicator(
            lineHeight: 8,
            percent: (pct / 100).clamp(0.0, 1.0),
            progressColor: color,
            backgroundColor: color.withOpacity(0.12),
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          // Skill chips — horizontally scrollable, no wrap overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: job.skills.take(6).map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white70),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / Error / No-profile states ────────────────────────────────────────
class _NoProfileBanner extends StatelessWidget {
  const _NoProfileBanner();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_add_alt_1_outlined,
              size: 64, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'Complete your profile first',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your skills in the Profile tab to get personalised ML-powered job recommendations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onLoad;
  const _EmptyView({required this.onLoad});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome_outlined,
            size: 64, color: AppTheme.primary),
        const SizedBox(height: 16),
        Text(
          'Ready to find your matches!',
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap below to run the ML recommendation engine.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onLoad,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Get My Recommendations'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(220, 48)),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppTheme.error),
          ),
          const SizedBox(height: 20),
          Text(
            'ML Server Offline',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Make sure your Flask ML server is running on your PC.\n\nRun: python app.py',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              minimumSize: const Size(160, 44),
            ),
          ),
        ],
      ),
    ),
  );
}

typedef RecommendationScreen = RecommendationBody;