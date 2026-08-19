import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class CustomRangePicker extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const CustomRangePicker({
    super.key,
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<CustomRangePicker> createState() => _CustomRangePickerState();
}

class _CustomRangePickerState extends State<CustomRangePicker> {
  late DateTime _start;
  late DateTime _end;

  final List<int> years = List.generate(11, (index) => DateTime.now().year - 10 + index);
  final List<String> months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Range',
              style: GoogleFonts.rubik(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select dates to see sales performance.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            
            _buildDatePickerSection('START DATE', _start, (newDate) {
              setState(() => _start = newDate);
            }),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(color: Color(0xFFF2F4F5), height: 1),
            ),
            
            _buildDatePickerSection('END DATE', _end, (newDate) {
              setState(() => _end = newDate);
            }),
            
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.outline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_start.isAfter(_end)) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Start date must be before end date.'))
                         );
                         return;
                      }
                      Navigator.pop(context, DateTimeRange(start: _start, end: _end));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text(
                      'APPLY',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerSection(String title, DateTime current, Function(DateTime) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppTheme.accent,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Year Dropdown
            _dropdown<int>(
              items: years,
              value: current.year,
              flex: 3,
              label: (y) => y.toString(),
              onChanged: (y) {
                if (y != null) {
                  onChanged(DateTime(y, current.month, current.day));
                }
              },
            ),
            const SizedBox(width: 8),
            // Month Dropdown
            _dropdown<int>(
              items: List.generate(12, (i) => i + 1),
              value: current.month,
              flex: 3,
              label: (m) => months[m - 1],
              onChanged: (m) {
                if (m != null) {
                  onChanged(DateTime(current.year, m, current.day));
                }
              },
            ),
            const SizedBox(width: 8),
            // Day Dropdown
            _dropdown<int>(
              items: List.generate(_daysInMonth(current.year, current.month), (i) => i + 1),
              value: current.day > _daysInMonth(current.year, current.month) 
                ? _daysInMonth(current.year, current.month) 
                : current.day,
              flex: 2,
              label: (d) => d.toString().padLeft(2, '0'),
              onChanged: (d) {
                if (d != null) {
                  onChanged(DateTime(current.year, current.month, d));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required List<T> items,
    required T value,
    required int flex,
    required String Function(T) label,
    required Function(T?) onChanged,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, color: AppTheme.outline, size: 20),
            style: GoogleFonts.inter(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            items: items.map((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(label(item)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
