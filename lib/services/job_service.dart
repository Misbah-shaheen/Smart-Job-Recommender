// services/job_service.dart
// Responsibilities:
//  1. Load jobs from local JSON asset (offline, compiled into APK)
//  2. Filter jobs by keyword / work-type / salary / experience
//  3. RANK filtered jobs using a weighted scoring system (iii-c requirement)
//  4. Call Flask /recommend for TF-IDF + Cosine Similarity ML recommendations
//  5. Call Flask /skill_gap for skill gap analysis
//
// PERFORMANCE FIXES (25,000 jobs):
//  • JSON parsing moved to a background isolate via compute()
//  • _buildSkillDemandMap() result is cached — built once, reused forever
//  • filterJobs() scoring moved to a background isolate
//  • SkillGapScreen uses a searchable list instead of a 25k-item DropdownButton

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/job_model.dart';
import '../utils/app_constants.dart';

// ─── Top-level helpers for compute() ─────────────────────────────────────────
// compute() requires top-level functions; closures don't work across isolates.

List<JobModel> _parseJobsIsolate(String jsonStr) {
  final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
  final jobsJson = decoded['jobs'] as List<dynamic>;
  final seen = <int>{};
  return jobsJson
      .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
      .where((job) => seen.add(job.id))
      .toList();
}

class _FilterParams {
  final List<JobModel> jobs;
  final String query;
  final String? workType;
  final int? maxSalary;
  final int? maxExperience;
  final List<String> userSkills;
  const _FilterParams({
    required this.jobs,
    required this.query,
    required this.workType,
    required this.maxSalary,
    required this.maxExperience,
    required this.userSkills,
  });
}

List<JobModel> _filterAndRankIsolate(_FilterParams p) {
  final userSkillSet = p.userSkills.map((s) => s.toLowerCase().trim()).toSet();
  final q = p.query.toLowerCase().trim();

  // Step 1: Boolean filter
  final filtered = p.jobs.where((job) {
    final matchesQuery = q.isEmpty ||
        job.jobTitle.toLowerCase().contains(q) ||
        job.skills.any((s) => s.toLowerCase().contains(q)) ||
        job.description.toLowerCase().contains(q);
    final matchesWork =
        p.workType == null || p.workType == 'All' || job.workType == p.workType;
    final matchesSalary = p.maxSalary == null || job.salary <= p.maxSalary!;
    final matchesExp =
        p.maxExperience == null || job.experience <= p.maxExperience!;
    return matchesQuery && matchesWork && matchesSalary && matchesExp;
  }).toList();

  if (filtered.isEmpty) return filtered;

  // Step 2: Weighted scoring
  final Map<int, double> scoreMap = {};
  for (final job in filtered) {
    double score = 0.0;
    if (userSkillSet.isNotEmpty && job.skills.isNotEmpty) {
      final matched = job.skills
          .where((s) => userSkillSet.contains(s.toLowerCase().trim()))
          .length;
      score += (matched / job.skills.length) * 40.0;
    }
    if (q.isNotEmpty) {
      if (job.jobTitle.toLowerCase().contains(q)) score += 15.0;
      if (job.skills.any((s) => s.toLowerCase().contains(q))) score += 7.0;
      if (job.description.toLowerCase().contains(q)) score += 3.0;
    }
    switch (job.workType) {
      case 'Remote': score += 20.0; break;
      case 'Hybrid': score += 12.0; break;
      default:       score += 5.0;
    }
    score += (15.0 - (job.experience * 3.0)).clamp(0.0, 15.0);
    scoreMap[job.id] = score;
  }

  filtered.sort((a, b) =>
      (scoreMap[b.id] ?? 0).compareTo(scoreMap[a.id] ?? 0));

  final rawValues = scoreMap.values.toList();
  final minRaw = rawValues.reduce(min);
  final maxRaw = rawValues.reduce(max);
  final rawRange = maxRaw - minRaw;

  return filtered.map((job) {
    final raw = scoreMap[job.id] ?? 0;
    final normalised = rawRange < 0.001
        ? 72.0
        : 5.0 + ((raw - minRaw) / rawRange) * 93.0;
    return job.copyWithMatch(double.parse(normalised.toStringAsFixed(1)));
  }).toList();
}

// ─── JobService ───────────────────────────────────────────────────────────────
class JobService {
  List<JobModel>? _cachedJobs;

  // FIX #1: Cache the demand map — was rebuilt on EVERY call, iterating
  // all 25k jobs each time → main-thread freeze → crash.
  Map<String, int>? _cachedDemandMap;

  // ─── 1. LOAD FROM LOCAL JSON ASSET ──────────────────────────────────
  // FIX #2: compute() moves JSON parsing to a background isolate so the
  // UI thread is never blocked during the heavy parse of 25k records.
  Future<List<JobModel>> loadAllJobs() async {
    if (_cachedJobs != null) return _cachedJobs!;
    final jsonStr = await rootBundle.loadString(AppConstants.jobsAssetPath);
    _cachedJobs = await compute(_parseJobsIsolate, jsonStr);
    return _cachedJobs!;
  }

  // ─── 2 + 3. FILTER THEN RANK JOBS ───────────────────────────────────
  // FIX #3: Scoring loop runs in a background isolate via compute().
  Future<List<JobModel>> filterJobs({
    required String query,
    String? workType,
    int? maxSalary,
    int? maxExperience,
    List<String> userSkills = const [],
  }) async {
    final all = await loadAllJobs();
    return compute(
      _filterAndRankIsolate,
      _FilterParams(
        jobs: all,
        query: query,
        workType: workType,
        maxSalary: maxSalary,
        maxExperience: maxExperience,
        userSkills: userSkills,
      ),
    );
  }

  // ─── 4. ML RECOMMENDATIONS VIA FLASK ────────────────────────────────
  Future<List<JobModel>> getRecommendations(List<String> skills) async {
    try {
      final uri = Uri.parse(AppConstants.recommendEndpoint);
      final response = await http
          .post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'skills': skills, 'top_n': 5}))
          .timeout(const Duration(seconds: AppConstants.httpTimeoutSeconds));

      if (response.statusCode != 200) {
        throw Exception(
            'Flask API error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['recommendations'] as List<dynamic>;
      final seen = <int>{};
      final deduped = list
          .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
          .where((job) => seen.add(job.id))
          .toList();

      if (deduped.length < 5) {
        final local = await _getLocalRecommendations(skills, topN: 5);
        deduped.addAll(
            local.where((j) => !seen.contains(j.id)).take(5 - deduped.length));
      }
      return deduped;
    } catch (_) {
      return _getLocalRecommendations(skills, topN: 5);
    }
  }

  Future<List<JobModel>> _getLocalRecommendations(List<String> skills,
      {int topN = 5}) async {
    final all = await loadAllJobs();
    final userSet = skills.map((s) => s.toLowerCase().trim()).toSet();
    if (userSet.isEmpty) return all.take(topN).toList();

    final scored = all.map((job) {
      final jobSet = job.skills.map((s) => s.toLowerCase().trim()).toSet();
      if (jobSet.isEmpty) return MapEntry(job, 0.0);
      final intersection = userSet.intersection(jobSet).length;
      final union = userSet.union(jobSet).length;
      return MapEntry(job, (intersection / union) * 100.0);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored
        .take(topN)
        .map((e) =>
        e.key.copyWithMatch(double.parse(e.value.toStringAsFixed(1))))
        .toList();
  }

  // ─── 5. SKILL GAP VIA FLASK ─────────────────────────────────────────
  Future<Map<String, List<String>>> getSkillGap({
    required List<String> userSkills,
    required int jobId,
  }) async {
    try {
      final uri = Uri.parse(AppConstants.skillGapEndpoint);
      final response = await http
          .post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_skills': userSkills, 'job_id': jobId}))
          .timeout(const Duration(seconds: AppConstants.httpTimeoutSeconds));

      if (response.statusCode != 200) {
        throw Exception('Skill gap API error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final missing = List<String>.from(data['missing_skills'] ?? []);
      final matching = List<String>.from(data['matching_skills'] ?? []);

      final demandMap = await _buildSkillDemandMap(); // cached
      missing.sort((a, b) => (demandMap[b.toLowerCase()] ?? 0)
          .compareTo(demandMap[a.toLowerCase()] ?? 0));

      return {'matching': matching, 'missing': missing};
    } catch (_) {
      return _computeSkillGapLocally(userSkills: userSkills, jobId: jobId);
    }
  }

  Future<Map<String, List<String>>> _computeSkillGapLocally({
    required List<String> userSkills,
    required int jobId,
  }) async {
    final all = await loadAllJobs();
    final job = all.firstWhere(
          (j) => j.id == jobId,
      orElse: () => throw Exception('Job $jobId not found in local data'),
    );

    final userSkillSet = userSkills.map((s) => s.toLowerCase().trim()).toSet();
    final jobSkills = job.skills.map((s) => s.toLowerCase().trim()).toList();

    final matching = jobSkills.where((s) => userSkillSet.contains(s)).toList();
    final missing = jobSkills.where((s) => !userSkillSet.contains(s)).toList();

    final demandMap = await _buildSkillDemandMap(); // cached
    missing.sort((a, b) => (demandMap[b] ?? 0).compareTo(demandMap[a] ?? 0));

    return {'matching': matching, 'missing': missing};
  }

  // ─── SKILL DEMAND MAP ────────────────────────────────────────────────
  // FIX #1 (continued): result cached after first build. Previously this
  // was rebuilt on every call, looping all 25k jobs each time.
  Future<Map<String, int>> _buildSkillDemandMap() async {
    if (_cachedDemandMap != null) return _cachedDemandMap!;
    final all = await loadAllJobs();
    final Map<String, int> freq = {};
    for (final job in all) {
      for (final skill in job.skills) {
        final key = skill.toLowerCase().trim();
        freq[key] = (freq[key] ?? 0) + 1;
      }
    }
    _cachedDemandMap = freq;
    return freq;
  }

  Future<Map<String, int>> getSkillDemandMap() => _buildSkillDemandMap();
}