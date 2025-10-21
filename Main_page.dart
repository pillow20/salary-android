import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// --- DATA MODEL (Optimized) ---
enum ShiftType { day, night }

class ShiftScheduleData {
  int _currentYear;
  int _currentMonth; // 0 for January, 11 for December

  // Определяем начальные даты для двух повторяющихся шаблонов смен
  static final DateTime _dayStart = DateTime(2025, 1, 3);
  static final DateTime _nightStart = DateTime(2025, 1, 6);
  // График - 2 дня работы / 6 дней отдыха. Полный цикл - 8 дней.

  ShiftScheduleData()
      : _currentYear = DateTime.now().year,
        _currentMonth = DateTime.now().month - 1;

  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth; // 0-indexed

  String get selectedMonthDisplay {
    final date = DateTime(_currentYear, _currentMonth + 1);
    // ЯВНОЕ ИСПОЛЬЗОВАНИЕ РУССКОЙ ЛОКАЛИ 'ru'
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

  // --- ЛОГИКА ОПТИМИЗАЦИИ: РАСЧЕТ СМЕНЫ НА ЛЕТУ ---
  ShiftType? _calculateShift(DateTime date) {
    ShiftType? checkShift(DateTime startDate, ShiftType type) {
      final Duration diff = date.difference(startDate);
      final int offset = diff.inDays;

      // Используем (offset % 8 + 8) % 8 для корректной работы с отрицательными смещениями
      final int cycleDay = (offset % 8 + 8) % 8;

      // Рабочие дни - это дни 0 и 1 цикла
      if (cycleDay == 0 || cycleDay == 1) {
        return type;
      }
      return null;
    }

    // 1. Проверяем дневную смену
    ShiftType? dayShift = checkShift(_dayStart, ShiftType.day);
    if (dayShift != null) {
      return dayShift;
    }

    // 2. Проверяем ночную смену
    ShiftType? nightShift = checkShift(_nightStart, ShiftType.night);
    if (nightShift != null) {
      return nightShift;
    }

    // Смена отсутствует (выходной)
    return null;
  }
}

// --- UI COMPONENTS ---
void main() async {
  // Инициализация данных локали 'ru' для пакета intl
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
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 28),
          titleLarge: TextStyle(fontSize: 20),
          titleMedium: TextStyle(fontSize: 18),
          bodyLarge: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 12),
          labelSmall: TextStyle(fontSize: 13),
        ),
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
          child: SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                margin: const EdgeInsets.all(10),
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
                  children: <Widget>[
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: <Widget>[
          Text(
            'Муринский хлебокомбинат',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'бригада номер 2',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.normal,
                ),
            textAlign: TextAlign.center,
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
        children: <Widget>[
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildActionButton(
          context,
          'Расчет зарплаты',
          () {
            debugPrint('Расчет зарплаты button pressed');
          },
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          context,
          'Расчет в выходной день',
          () {
            debugPrint('Расчет в выходной день button pressed');
          },
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          context,
          'Кнопка 3',
          () {
            debugPrint('Кнопка 3 button pressed');
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3498DB).withOpacity(0.3),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEEEEEE),
            width: 2,
          ),
        ),
      ),
      child: Text(
        'График смен бригады № 2',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF2C3E50),
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.center,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildNavButton(context, Icons.arrow_back_ios_rounded, onPreviousMonth),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                scheduleData.selectedMonthDisplay,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          _buildNavButton(context, Icons.arrow_forward_ios_rounded, onNextMonth),
        ],
      ),
    );
  }

  Widget _buildNavButton(
      BuildContext context, IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3498DB), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: const Color(0xFF3498DB),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }
}

class CalendarGrid extends StatelessWidget {
  final ShiftScheduleData scheduleData;

  const CalendarGrid({required this.scheduleData, super.key});

  final List<String> _dayNames = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: _dayNames.length,
            itemBuilder: (BuildContext context, int index) {
              return DayHeader(dayName: _dayNames[index]);
            },
          ),
          const SizedBox(height: 6), 

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              // **УВЕЛИЧЕНИЕ ВЫСОТЫ ЯЧЕЙКИ: 0.85**
              childAspectRatio: 0.85, 
            ),
            itemCount: scheduleData.startDayOfWeek - 1 + scheduleData.daysInMonth,
            itemBuilder: (BuildContext context, int index) {
              if (index < scheduleData.startDayOfWeek - 1) {
                return const EmptyDayCell();
              } else {
                final day = index - (scheduleData.startDayOfWeek - 1) + 1;
                final bool isWeekend = (index % 7 == 5 || index % 7 == 6);
                return DayCell(
                  dayNumber: day,
                  shiftType: scheduleData.getShiftType(day),
                  isWeekend: isWeekend,
                  isToday: scheduleData.isToday(day),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class DayHeader extends StatelessWidget {
  const DayHeader({required this.dayName, super.key});

  final String dayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        dayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF495057),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class DayCell extends StatelessWidget {
  const DayCell({
    required this.dayNumber,
    required this.shiftType,
    required this.isWeekend,
    required this.isToday,
    super.key,
  });

  final int dayNumber;
  final ShiftType? shiftType;
  final bool isWeekend;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    Color textColor = const Color(0xFF2C3E50);
    Color backgroundColor = Colors.white;
    Border? border;
    Gradient? gradient;
    String? label;

    // --- Логика цветов и меток ---
    if (isToday) {
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      );
      textColor = Colors.white;
    } else if (shiftType == ShiftType.day) {
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4299E1), Color(0xFF2C5282)],
      );
      textColor = Colors.white;
      border = Border.all(color: const Color(0xFF2C5282));
      label = 'день';
    } else if (shiftType == ShiftType.night) {
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA0522D), Color(0xFF5D2E0F)],
      );
      textColor = Colors.white;
      border = Border.all(color: const Color(0xFF5D2E0F));
      label = 'ночь';
    } else if (isWeekend) {
      textColor = const Color(0xFFE74C3C); 
      backgroundColor = const Color(0xFFFDF2F2); 
      border = Border.all(color: const Color(0xFFFADBD8), width: 1);
    }
    // ----------------------------

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        border: border,
        boxShadow: isToday ? [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 4.0), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              '$dayNumber',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    // Цифры дня: 11.0
                    fontSize: 11.0, 
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            // Надпись "день/ночь" под номером
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0), 
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        // Надписи смен: 9.0
                        fontSize: 9.0, 
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyDayCell extends StatelessWidget {
  const EmptyDayCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
      ),
    );
  }
}