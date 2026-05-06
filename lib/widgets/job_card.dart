// widgets/job_card.dart
// Shows job info with company, location, salary, work type + Apply button.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';

class JobCard extends StatefulWidget {
  final JobModel job;
  const JobCard({super.key, required this.job});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _applied   = false;
  bool _applying  = false;
  bool _expanded  = false;

  @override
  void initState() {
    super.initState();
    _checkApplied();
  }

  Future<void> _checkApplied() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _applied = prefs.getBool('applied_${widget.job.id}') ?? false);
    }
  }

  Future<void> _apply() async {
    if (_applied || _applying) return;
    setState(() => _applying = true);

    // Simulate a brief "submitting" delay
    await Future.delayed(const Duration(milliseconds: 800));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('applied_${widget.job.id}', true);

    if (!mounted) return;
    setState(() { _applied = true; _applying = false; });

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Submitted! 🎉',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'You applied to ${widget.job.jobTitle} at ${widget.job.company}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final wtColor = _workTypeColor(job.workType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _applied
              ? AppTheme.success.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: company logo placeholder + title + work type badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _companyColor(job.company),
                            _companyColor(job.company).withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          job.company.isNotEmpty
                              ? job.company[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title + company
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.jobTitle,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            job.company,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Work type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: wtColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: wtColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        job.workType,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: wtColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Info row: location, salary, experience
                Row(
                  children: [
                    _infoChip(Icons.location_on_outlined,
                        job.location.split(',').first, Colors.white38),
                    const SizedBox(width: 10),
                    _infoChip(Icons.attach_money_rounded,
                        '\$${(job.salary / 1000).toStringAsFixed(0)}k/yr',
                        AppTheme.success),
                    const SizedBox(width: 10),
                    _infoChip(Icons.work_history_outlined,
                        '${job.experience}+ yrs', Colors.white38),
                  ],
                ),
                const SizedBox(height: 10),

                // Match percentage bar (if available)
                if (job.matchPercentage != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (job.matchPercentage! / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(
                              job.matchPercentage! >= 70
                                  ? AppTheme.success
                                  : job.matchPercentage! >= 40
                                      ? AppTheme.warning
                                      : AppTheme.error,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${job.matchPercentage!.toStringAsFixed(0)}% match',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: job.matchPercentage! >= 70
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Skills
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: job.skills.take(4).map((s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white60)),
                  )).toList()
                  ..addAll(job.skills.length > 4
                      ? [Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('+${job.skills.length - 4} more',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppTheme.primary)),
                        )]
                      : []),
                ),

                // Expanded details
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  _detailRow(Icons.school_outlined,
                      'Qualifications', job.qualifications),
                  const SizedBox(height: 6),
                  _detailRow(Icons.business_outlined,
                      'Company Size', job.companySize),
                  if (job.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      job.description,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white54,
                          height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ],
            ),
          ),

          // ── Action bar ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Expand/collapse details
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white38,
                    ),
                    label: Text(
                      _expanded ? 'Less' : 'Details',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white38),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                Container(width: 1, height: 24, color: Colors.white12),

                // Apply button
                Expanded(
                  child: TextButton(
                    onPressed: _applied ? null : _apply,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _applied
                                    ? Icons.check_circle_rounded
                                    : Icons.send_rounded,
                                size: 14,
                                color: _applied
                                    ? AppTheme.success
                                    : AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _applied ? 'Applied ✓' : 'Apply Now',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _applied
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
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

  Widget _infoChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: GoogleFonts.inter(fontSize: 11, color: color)),
    ],
  );

  Widget _detailRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.white38),
      const SizedBox(width: 6),
      Text('$label: ',
          style: GoogleFonts.inter(
              fontSize: 12, color: Colors.white38)),
      Expanded(
        child: Text(value,
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.white70)),
      ),
    ],
  );

  Color _workTypeColor(String wt) {
    switch (wt) {
      case 'Remote': return const Color(0xFF48CAE4);
      case 'Hybrid': return const Color(0xFFFFD93D);
      default:       return const Color(0xFF6BCB77);
    }
  }

  Color _companyColor(String name) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF48CAE4),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFFFF922B),
      const Color(0xFFE040FB),
      const Color(0xFF00BCD4),
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }
}
