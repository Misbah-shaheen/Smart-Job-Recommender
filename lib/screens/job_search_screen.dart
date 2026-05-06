// screens/job_search_screen.dart — Body only (no Scaffold/AppBar inside)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../services/app_provider.dart';
import '../models/job_model.dart';
import '../utils/app_theme.dart';
import '../widgets/job_card.dart';
import '../widgets/filter_bottom_sheet.dart';

class JobSearchBody extends StatefulWidget {
  const JobSearchBody({super.key});
  @override
  State<JobSearchBody> createState() => _JobSearchBodyState();
}

class _JobSearchBodyState extends State<JobSearchBody> {
  final _searchCtrl = TextEditingController();
  String? _workType;
  int?    _maxSalary;
  int?    _maxExp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadJobsIfNeeded();
    });
  }

  void _onSearchChanged(String q) => context.read<AppProvider>().loadJobs(
    query: q, workType: _workType,
    maxSalary: _maxSalary, maxExperience: _maxExp,
  );

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E3A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FilterBottomSheet(
        currentWorkType: _workType,
        currentMaxSalary: _maxSalary,
        currentMaxExp: _maxExp,
        onApply: (wt, ms, me) {
          setState(() { _workType = wt; _maxSalary = ms; _maxExp = me; });
          context.read<AppProvider>().loadJobs(
              query: _searchCtrl.text,
              workType: wt, maxSalary: ms, maxExperience: me);
        },
      ),
    );
  }

  bool get _hasFilters => _workType != null || _maxSalary != null || _maxExp != null;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────────
        Container(
          color: const Color(0xFF1A1A35),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search jobs, skills…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () { _searchCtrl.clear(); _onSearchChanged(''); })
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter button
              GestureDetector(
                onTap: _openFilters,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _hasFilters
                        ? AppTheme.primary
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasFilters
                          ? AppTheme.primary
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _hasFilters ? Colors.white : Colors.white54,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Active filter chips ───────────────────────────────────
        if (_hasFilters)
          Container(
            color: const Color(0xFF13132B),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded,
                    size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_workType != null)
                          _chip(_workType!, () {
                            setState(() => _workType = null);
                            _onSearchChanged(_searchCtrl.text);
                          }),
                        if (_maxSalary != null)
                          _chip('≤ \$${_maxSalary! ~/ 1000}k', () {
                            setState(() => _maxSalary = null);
                            _onSearchChanged(_searchCtrl.text);
                          }),
                        if (_maxExp != null)
                          _chip('≤ $_maxExp yrs', () {
                            setState(() => _maxExp = null);
                            _onSearchChanged(_searchCtrl.text);
                          }),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() { _workType=null; _maxSalary=null; _maxExp=null; });
                    _onSearchChanged(_searchCtrl.text);
                  },
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: const Size(0,0)),
                  child: Text('Clear all',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.error)),
                ),
              ],
            ),
          ),

        // ── Job list ──────────────────────────────────────────────
        Expanded(
          child: Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.loadingJobs) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (provider.error != null) {
                return _ErrorState(message: provider.error!);
              }
              final jobs = provider.filteredJobs;
              if (jobs.isEmpty) return _EmptyState(query: _searchCtrl.text);
              return _JobList(jobs: jobs);
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppTheme.primary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 13, color: AppTheme.primary),
          ),
        ],
      ),
    ),
  );
}

class _JobList extends StatelessWidget {
  final List<JobModel> jobs;
  const _JobList({required this.jobs});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${jobs.length} jobs found',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: jobs.length,
              itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 300),
                child: SlideAnimation(
                  verticalOffset: 24,
                  child: FadeInAnimation(child: JobCard(job: jobs[i])),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded,
          size: 56, color: Colors.white.withOpacity(0.15)),
      const SizedBox(height: 12),
      Text(query.isEmpty ? 'No jobs available' : 'No results for "$query"',
          style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary)),
      const SizedBox(height: 6),
      Text('Try a different search or adjust filters.',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.6))),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.error)),
      ]),
    ),
  );
}

// Legacy alias so HomeScreen import still works
typedef JobSearchScreen = JobSearchBody;