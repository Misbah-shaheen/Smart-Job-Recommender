// widgets/filter_bottom_sheet.dart — Dark themed, professional filter sheet

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class FilterBottomSheet extends StatefulWidget {
  final String? currentWorkType;
  final int?    currentMaxSalary;
  final int?    currentMaxExp;
  final void Function(String? workType, int? maxSalary, int? maxExp) onApply;

  const FilterBottomSheet({
    super.key,
    this.currentWorkType,
    this.currentMaxSalary,
    this.currentMaxExp,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _workType;
  double  _maxSalary = 150000;
  double  _maxExp    = 10;

  static const _workTypes = ['All', 'Remote', 'Hybrid', 'Onsite'];

  @override
  void initState() {
    super.initState();
    _workType  = widget.currentWorkType;
    _maxSalary = (widget.currentMaxSalary ?? 150000).toDouble();
    _maxExp    = (widget.currentMaxExp    ?? 10).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Jobs',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              TextButton(
                onPressed: () => setState(() {
                  _workType = null; _maxSalary = 150000; _maxExp = 10;
                }),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: Text('Reset',
                    style: GoogleFonts.inter(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Work Type ────────────────────────────────────────────
          _sectionLabel('Work Type'),
          const SizedBox(height: 10),
          Row(
            children: _workTypes.map((type) {
              final selected = (type == 'All' && _workType == null) || _workType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _workType = type == 'All' ? null : type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _workTypeIcon(type),
                            size: 18,
                            color: selected ? Colors.white : Colors.white54,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected ? Colors.white : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Salary slider ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Max Salary'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${(_maxSalary / 1000).toStringAsFixed(0)}k',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _maxSalary,
              min: 30000,
              max: 150000,
              divisions: 24,
              onChanged: (v) => setState(() => _maxSalary = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$30k', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
              Text('\$150k', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Experience slider ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Max Experience'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_maxExp.toInt()} yrs',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.secondary,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.secondary,
              overlayColor: AppTheme.secondary.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _maxExp,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => setState(() => _maxExp = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 yrs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
              Text('10 yrs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 28),

          // ── Apply button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(
                  _workType,
                  _maxSalary >= 150000 ? null : _maxSalary.toInt(),
                  _maxExp    >= 10     ? null : _maxExp.toInt(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Apply Filters',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white70),
  );

  IconData _workTypeIcon(String type) {
    switch (type) {
      case 'Remote': return Icons.home_work_rounded;
      case 'Hybrid': return Icons.sync_alt_rounded;
      case 'Onsite': return Icons.location_on_rounded;
      default:       return Icons.work_rounded;
    }
  }
}
