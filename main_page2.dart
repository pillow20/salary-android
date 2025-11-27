import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// --- DATA MODEL ---
enum ShiftType { day, night }

class ShiftScheduleData {
  int _currentYear;
  int _currentMonth;

  static final DateTime _dayStart = DateTime(2025, 1, 3);
  static final DateTime _nightStart = DateTime(2025, 1, 6);

  ShiftScheduleData()
      : _currentYear = DateTime.now().year,
        _currentMonth = DateTime.now().month - 1;

  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;

  String get selectedMonthDisplay {
    final date = DateTime(_currentYear, _currentMonth + 1);
    return DateFormat.yMMMM('ru').format(date);
  }

  int get daysInMonth {
    return DateTime(_currentYear, _currentMonth + 2, 0).day;
  }

  int get startDayOfWeek {
    final firstDay = DateTime(_currentYear, _currentMonth + 1, 1);
    return firstDay.weekday;
  }

  ShiftType? getShiftType(int day) {
    final date = DateTime(_currentYear, _currentMonth + 1, day);
    return _calculateShift(date);
  }

  bool isToday(int day) {
    final now = DateTime.now();
    return day == now.day &&
        _currentMonth == now.month - 1 &&
        _currentYear == now.year;
  }

  void goToPreviousMonth() {
    _currentMonth--;
    if (_currentMonth < 0) {
      _currentMonth = 11;
      _currentYear--;
    }
  }

  void goToNextMonth() {
    _currentMonth++;
    if (_currentMonth > 11) {
      _currentMonth = 0;
      _currentYear++;
    }
  }

  // --- SHIFT CALCULATION ---
  ShiftType? _calculateShift(DateTime date) {
    ShiftType? checkShift(DateTime startDate, ShiftType type) {
      final Duration diff = date.difference(startDate);
      final int offset = diff.inDays;
      final int cycleDay = (offset % 8 + 8) % 8;

      if (cycleDay == 0 || cycleDay == 1) {
        return type;
      }
      return null;
    }

    final dayShift = checkShift(_dayStart, ShiftType.day);
    if (dayShift != null) return dayShift;

    final nightShift = checkShift(_nightStart, ShiftType.night);
    if (nightShift != null) return nightShift;

    return null;
  }
}

// --- UI ---
void main() async {
  await initializeDateFormatting('ru', null);
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'График смен бригады № 2',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: const ScheduleScreen(),
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late ShiftScheduleData _scheduleData;

  @override
  void initState() {
    super.initState();
    _scheduleData = ShiftScheduleData();
  }

  void _onPreviousMonthPressed() {
    setState(() {
      _scheduleData.goToPreviousMonth();
    });
  }

  void _onNextMonthPressed() {
    setState(() {
      _scheduleData.goToNextMonth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 20),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const HeaderSection(),
                      MainSection(
                        scheduleData: _scheduleData,
                        onPreviousMonth: _onPreviousMonthPressed,
                        onNextMonth: _onNextMonthPressed,
                      ),
                      const FooterSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: [
          Text(
            'Муринский хлебокомбинат',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'бригада номер 2',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

class MainSection extends StatelessWidget {
  final ShiftScheduleData scheduleData;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MainSection({
    required this.scheduleData,
    required this.onPreviousMonth,
    required this.onNextMonth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: [
          const ActionButtons(),
          const SizedBox(height: 25),
          const ScheduleTitle(),
          const SizedBox(height: 25),
          CalendarHeader(
            scheduleData: scheduleData,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
          ),
          const SizedBox(height: 20),
          CalendarGrid(scheduleData: scheduleData),
        ],
      ),
    );
  }
}

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(context, 'Расчет зарплаты', () {}),
        const SizedBox(height: 16),
        _buildButton(context, 'Расчет в выходной день', () {}),
        const SizedBox(height: 16),
        _buildButton(context, 'Кнопка 3', () {}),
      ],
    );
  }

  Widget _buildButton(BuildContext context, String text, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class ScheduleTitle extends StatelessWidget {
  const ScheduleTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 2)),
      ),
      child: Text(
        'График смен бригады № 2',
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class CalendarHeader extends StatelessWidget {
  final ShiftScheduleData scheduleData;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const CalendarHeader({
    required this.scheduleData,
    required this.onPreviousMonth,
    required this.onNextMonth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _navBtn(Icons.arrow_back_ios_rounded, onPreviousMonth),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              scheduleData.selectedMonthDisplay,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
          ),
        ),
        _navBtn(Icons.arrow_forward_ios_rounded, onNextMonth),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Color(0xFF3498DB), width: 2),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        color: const Color(0xFF3498DB),
      ),
    );
  }
}

class CalendarGrid extends StatelessWidget {
  final ShiftScheduleData scheduleData;

  const CalendarGrid({required this.scheduleData, super.key});

  final List<String> _names = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: 7,
          itemBuilder: (_, i) => Center(
            child: Text(
              _names[i],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
          ),
          itemCount: scheduleData.startDayOfWeek - 1 + scheduleData.daysInMonth,
          itemBuilder: (_, index) {
            if (index < scheduleData.startDayOfWeek - 1) {
              return const SizedBox.shrink();
            }

            final day =
                index - (scheduleData.startDayOfWeek - 1) + 1;
            final isWeekend = (index % 7 == 5 || index % 7 == 6);

            return DayCell(
              dayNumber: day,
              shiftType: scheduleData.getShiftType(day),
              isWeekend: isWeekend,
              isToday: scheduleData.isToday(day),
            );
          },
        ),
      ],
    );
  }
}

class DayCell extends StatelessWidget {
  final int dayNumber;
  final ShiftType? shiftType;
  final bool isWeekend;
  final bool isToday;

  const DayCell({
    super.key,
    required this.dayNumber,
    required this.shiftType,
    required this.isWeekend,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor = const Color(0xFF2C3E50);
    Gradient? gradient;
    String? label;

    if (isToday) {
      gradient = const LinearGradient(
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      );
      textColor = Colors.white;
    } else if (shiftType == ShiftType.day) {
      gradient = const LinearGradient(
        colors: [Color(0xFF4299E1), Color(0xFF2C5282)],
      );
      textColor = Colors.white;
      label = 'день';
    } else if (shiftType == ShiftType.night) {
      gradient = const LinearGradient(
        colors: [Color(0xFFA0522D), Color(0xFF5D2E0F)],
      );
      textColor = Colors.white;
      label = 'ночь';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? Colors.white : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '$dayNumber',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
          ),
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 10, color: textColor),
            ),
        ],
      ),
    );
  }
}

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      padding: const EdgeInsets.all(20),
      child: Text(
        '© 2025 "Алексей Агафонов" - Расчет зарплаты',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
