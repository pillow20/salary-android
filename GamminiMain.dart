import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === 1. ENUMS И МОДЕЛИ ДАННЫХ ===

// ТИПЫ СМЕН: 2 дневных, 2 ночных + 1 производная
enum ShiftType {
  none,
  green1, // 'день 1'
  green2, // 'день 2'
  brown1, // 'ночь 1'
  brown2, // 'ночь 2'
  afterBrown, // 'с ночи' (отсыпной)
}

class ShiftData {
  final DateTime date;
  final ShiftType type;
  bool isDisabled;
  double hours;
  double nightHours;
  String label;

  ShiftData({
    required this.date,
    required this.type,
    this.isDisabled = false,
    this.hours = 0,
    this.nightHours = 0,
    this.label = '',
  });

  String get dateKey => DateFormat('yyyy-MM-dd').format(date);
}

// === 2. КОНСТАНТЫ РАСЧЕТА ЗАРПЛАТЫ ===

const double BASE_HOURS = 164.3333; // Средняя норма часов
const double NIGHT_RATE = 0.4;
const double HARM_RATE = 0.04;
const double NDFL_RATE = 0.13;

// === 3. ОСНОВНОЙ WIDGET ПРИЛОЖЕНИЯ ===

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru_RU';
  await initializeDateFormatting('ru_RU', null);
  runApp(const ShiftSchedulerApp());
}

class ShiftSchedulerApp extends StatelessWidget {
  const ShiftSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'График смен',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Arial',
      ),
      home: const ScheduleScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Переменные состояния
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, ShiftData> _allShifts = {};
  Map<DateTime, bool> _disabledDates = {}; // Состояние отсутствия на смене

  // Поля калькулятора
  final TextEditingController _okladController =
      TextEditingController(text: '48910');
  final TextEditingController _premiumController =
      TextEditingController(text: '40');
  double _totalHours = 0;
  double _nightHours = 0;
  int _shiftCount = 0;
  String _salaryResult = '';

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _generateShifts();
    _loadDisabledDates();
  }

  // === 4. ЛОГИКА ГЕНЕРАЦИИ СМЕН (КОРРЕКТНЫЙ ЦИКЛ 8 ДНЕЙ) ===

  void _generateShifts() {
    final Map<DateTime, ShiftData> shifts = {};
    // День, с которого начинается цикл (Day 1 - Green1). 3 января 2025 года.
    final DateTime cycleStart = DateTime(2025, 1, 3);
    final DateTime endDate = DateTime(2031, 1, 1);

    // Вспомогательная функция для добавления смены
    void addShift(DateTime date, ShiftType type,
        {String label = '', double hours = 0, double nightHours = 0}) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      shifts[normalizedDate] = ShiftData(
        date: normalizedDate,
        type: type,
        label: label,
        hours: hours,
        nightHours: nightHours,
      );
    }

    int dayIndex = 0;
    for (DateTime currentDate = cycleStart;
        currentDate.isBefore(endDate);
        currentDate = currentDate.add(const Duration(days: 1))) {
      
      // Индекс в 8-дневном цикле: 0, 1, 2, 3, 4, 5, 6, 7
      final int cycleDay = dayIndex % 8;

      ShiftType? currentShiftType;
      double hours = 0;
      double nightHours = 0;
      String label = '';
      
      // ИСПРАВЛЕННЫЙ ЦИКЛ: D1, D2, OFF, N1, N2, AfterN, OFF, OFF
      switch (cycleDay) {
        case 0: // Day 1
          currentShiftType = ShiftType.green1;
          hours = 11;
          label = 'день 1';
          break;
        case 1: // Day 2
          currentShiftType = ShiftType.green2;
          hours = 11;
          label = 'день 2';
          break;
        case 2: // Выходной (Off)
          currentShiftType = ShiftType.none;
          break;
        case 3: // Night 1
          currentShiftType = ShiftType.brown1;
          hours = 11;
          nightHours = 7.5;
          label = 'ночь 1';
          break;
        case 4: // Night 2
          currentShiftType = ShiftType.brown2;
          hours = 11;
          nightHours = 7.5;
          label = 'ночь 2';
          break;
        case 5: // After Night 2 (Смена "с ночи" / Отсыпной)
          currentShiftType = ShiftType.afterBrown;
          hours = 0; // ИСПРАВЛЕНО: Часы смены "с ночи" не оплачиваются
          nightHours = 0; // ИСПРАВЛЕНО: Ночные часы смены "с ночи" не оплачиваются
          label = 'с ночи';
          break;
        case 6: // Выходной (Off)
        case 7: // Выходной (Off)
        default:
          currentShiftType = ShiftType.none;
          break;
      }

      if (currentShiftType != ShiftType.none) {
        addShift(currentDate, currentShiftType!,
            label: label, hours: hours, nightHours: nightHours);
      }
      
      dayIndex++;
    }
    
    // Коррекция ночной смены, если она последняя в месяце (только 4 часа)
    shifts.forEach((date, shift) {
      if (shift.type == ShiftType.brown1 || shift.type == ShiftType.brown2) {
        DateTime nextDay = date.add(const Duration(days: 1));
        
        if (nextDay.month != date.month) {
          // Укороченная ночная смена на границе месяца
          shift.hours = 4;
          shift.nightHours = 2;
        }
      }
    });

    _allShifts = shifts;
    _updateMonthStats(_focusedDay);
  }

  // === 5. ЛОГИКА СТАТИСТИКИ И РАСЧЕТА ===

  void _updateMonthStats(DateTime month) {
    int shiftCount = 0;
    double totalHours = 0;
    double nightHours = 0;

    DateTime start = DateTime(month.year, month.month, 1);
    // Получаем последний день текущего месяца
    DateTime end = DateTime(month.year, month.month + 1, 0);

    for (DateTime date = start;
        date.isBefore(end.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (_allShifts.containsKey(normalizedDate) &&
          !_disabledDates.containsKey(normalizedDate)) {
        final shift = _allShifts[normalizedDate]!;
        
        // ИСПРАВЛЕНО: Учитываем только D1, D2, N1, N2 в общем количестве смен
        if (shift.type != ShiftType.afterBrown) {
          shiftCount++;
        }
        
        totalHours += shift.hours;
        nightHours += shift.nightHours;
      }
    }

    setState(() {
      _totalHours = totalHours;
      _nightHours = nightHours;
      _shiftCount = shiftCount;
    });
  }
  
  // === 6. ЛОКАЛЬНОЕ ХРАНЕНИЕ (shared_preferences) ===

  Future<void> _loadDisabledDates() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> disabledKeys = prefs.getStringList('disabledDates') ?? [];

    setState(() {
      _disabledDates = {
        for (var key in disabledKeys) DateFormat('yyyy-MM-dd').parse(key): true
      };
      _updateMonthStats(_focusedDay);
    });
  }

  Future<void> _saveDisabledDates() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> disabledKeys = _disabledDates.keys
        .map((date) => DateFormat('yyyy-MM-dd').format(date))
        .toList();
    await prefs.setStringList('disabledDates', disabledKeys);
  }

  // === 7. ЛОГИКА РАСЧЕТА ЗАРПЛАТЫ ===

  void _calculateSalary() {
    double oklad = double.tryParse(_okladController.text) ?? 0;
    double premiumPercent = double.tryParse(_premiumController.text) ?? 0;
    double hours = _totalHours;
    double nightHours = _nightHours;

    if (oklad == 0 || hours == 0) {
      setState(() {
        _salaryResult = 'Введите оклад и отработайте смены!';
      });
      return;
    }

    double baseRate = oklad / BASE_HOURS;
    double basePay = baseRate * hours;
    double premiumPay = basePay * (premiumPercent / 100);
    double nightPay = baseRate * nightHours * NIGHT_RATE;
    double totalBeforeHarm = basePay + premiumPay + nightPay;
    double harmAddition = totalBeforeHarm * HARM_RATE;
    double totalWithHarm = totalBeforeHarm + harmAddition;
    double ndfl = totalWithHarm * NDFL_RATE;
    double finalSalary = totalWithHarm - ndfl;

    final formatter =
        NumberFormat.currency(locale: 'ru_RU', symbol: 'руб.', decimalDigits: 2);

    setState(() {
      _salaryResult = '''
        1. Основная оплата: ${formatter.format(basePay)}
        2. Премия (${premiumPercent.toStringAsFixed(0)}%): ${formatter.format(premiumPay)}
        3. Доплата за ночь: ${formatter.format(nightPay)}
        4. Доплата за вредность (4%): ${formatter.format(harmAddition)}
        5. НДФЛ (13%): ${formatter.format(ndfl)}
        ---
        **К ВЫПЛАТЕ:** ${formatter.format(finalSalary)}
      ''';
    });
  }

  // === 8. WIDGETS И UI ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF667EEA), // body background
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'График смен бригады № 2',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2c3e50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCalendar(),
                      const SizedBox(height: 15),
                      _buildSummary(),
                      const SizedBox(height: 25),
                      _buildInstructionText(),
                      _buildCalculator(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2c3e50), Color(0xFF3498db)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: const Column(
        children: [
          Text(
            'Муринский хлебокомбинат',
            style: TextStyle(
              fontSize: 28.8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'бригада номер 2',
            style: TextStyle(
              fontSize: 20.8,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TableCalendar(
        locale: 'ru_RU',
        firstDay: DateTime.utc(2025, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        // Установка начала недели с понедельника
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 18.4,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2c3e50),
          ),
          leftChevronIcon: _buildNavButton(Icons.chevron_left),
          rightChevronIcon: _buildNavButton(Icons.chevron_right),
        ),
        calendarStyle: CalendarStyle(
          weekendTextStyle: const TextStyle(color: Color(0xFFe74c3c)),
          defaultDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          todayDecoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          todayTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          selectedDecoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        daysOfWeekHeight: 25,
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
            _updateMonthStats(focusedDay);
          });
        },
        // Кастомизация ячеек дня
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, focusedDay);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, focusedDay, isToday: true);
          },
          selectedBuilder: (context, day, focusedDay) {
            // isToday здесь не передается, поэтому логика переносится в _buildDayCell
            return _buildDayCell(day, focusedDay, isSelected: true);
          },
        ),
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          final normalizedSelectedDay =
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
          if (_allShifts.containsKey(normalizedSelectedDay)) {
            setState(() {
              if (_disabledDates.containsKey(normalizedSelectedDay)) {
                _disabledDates.remove(normalizedSelectedDay);
              } else {
                _disabledDates[normalizedSelectedDay] = true;
              }
              _saveDisabledDates(); // Сохраняем изменение
              _focusedDay = focusedDay;
              _selectedDay = selectedDay;
              _updateMonthStats(focusedDay);
            });
          }
        },
      ),
    );
  }

  Widget _buildNavButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF3498db), width: 2),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF3498db), size: 18),
    );
  }

  // ОБНОВЛЕННЫЙ МЕТОД: Обрабатывает новые типы смен, добавляет галочку для Today, 
  // и гарантирует, что стиль Today всегда приоритетен, даже при выборе.
  Widget _buildDayCell(DateTime day, DateTime focusedDay,
      {bool isToday = false, bool isSelected = false}) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final isShiftDay = _allShifts.containsKey(normalizedDay);
    final shift = isShiftDay ? _allShifts[normalizedDay] : null;
    final isDisabled = _disabledDates.containsKey(normalizedDay);

    // ИСПРАВЛЕНИЕ: Определяем фактический сегодняшний день.
    final now = DateTime.now();
    final normalizedNow = DateTime(now.year, now.month, now.day);
    final isActualToday = normalizedDay == normalizedNow;

    Color textColor = const Color(0xFF2c3e50);
    String label = '';
    BoxDecoration? decoration;

    if (isShiftDay && !isDisabled) {
      Color startColor = Colors.transparent;
      Color endColor = Colors.transparent;
      
      switch (shift!.type) {
        case ShiftType.green1:
          startColor = const Color(0xFF4299e1); // Более светлый синий
          endColor = const Color(0xFF2c5282);
          label = 'день 1';
          textColor = Colors.white;
          break;
        case ShiftType.green2:
          startColor = const Color(0xFF3498db); // Средний синий
          endColor = const Color(0xFF2980b9);
          label = 'день 2';
          textColor = Colors.white;
          break;
        case ShiftType.brown1:
          startColor = const Color(0xFFa0522d); // Более светлый коричневый
          endColor = const Color(0xFF5D2E0F);
          label = 'ночь 1';
          textColor = Colors.white;
          break;
        case ShiftType.brown2:
          startColor = const Color(0xFF8b4513); // Темно-коричневый
          endColor = const Color(0xFF5D2E0F);
          label = 'ночь 2';
          textColor = Colors.white;
          break;
        case ShiftType.afterBrown:
          startColor = const Color(0xFFd2a679);
          endColor = const Color(0xFFb08a5a);
          label = 'с ночи';
          textColor = const Color(0xFF5D2E0F);
          break;
        default:
          break;
      }
      
      // Назначаем градиент для всех смен, кроме выходных и пропущенных
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

      if (shift.type == ShiftType.afterBrown) {
          // Специальный стиль для "с ночи" (отсыпной)
          decoration = BoxDecoration(
            color: startColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF5D2E0F), width: 2),
            gradient: const LinearGradient(
              colors: [Color(0xFFf0d9c4), Color(0xFFe9d0bb)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          );
          textColor = const Color(0xFF5D2E0F);
      }

    } else if (isShiftDay && isDisabled) {
      // Стиль для пропущенной смены (бледный)
      textColor = Colors.grey;
      decoration = BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      );
      label = shift?.label ?? '';
    } else if (day.month == focusedDay.month && (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday)) {
      // Выходные (если это не сменный день)
      textColor = const Color(0xFFe74c3c);
      decoration = BoxDecoration(
        color: const Color(0xFFfdf2f2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFfadbd8), width: 1),
      );
    } else {
        // Обычные дни без смены (Off Days)
        decoration = BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
        );
    }

    // ВАЖНОЕ ИСПРАВЛЕНИЕ: Этот блок теперь использует isActualToday и должен быть последним
    // для обеспечения приоритета стиля "Сегодня" (градиент и белый текст), даже если день выбран.
    if (isActualToday) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      );
      textColor = Colors.white;
    }

    if (day.month != focusedDay.month) {
      textColor = textColor.withOpacity(0.5);
    }

    return Container(
      margin: const EdgeInsets.all(3.0),
      alignment: Alignment.center,
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row( // Используем Row для размещения номера дня и галочки
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.day.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              // Добавляем галочку, если это текущий день
              if (isActualToday) // ИСПОЛЬЗУЕМ isActualToday ДЛЯ НАДЕЖНОСТИ
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.white, // Белый для контраста на градиенте
                  ),
                ),
            ],
          ),
          if (label.isNotEmpty && !isDisabled)
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.8),
              ),
            ),
          if (isDisabled)
            const Text(
              'X',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    String formattedNight = _nightHours % 1 == 0
        ? _nightHours.toFixed(0)
        : _nightHours.toFixed(1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf1f8ff),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Смен: $_shiftCount | Часов: ${_totalHours.toFixed(1)} | Ночных: $formattedNight',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2c3e50),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInstructionText() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text(
        'Если вас не было на какой-то смене — нажмите на неё, и она исчезнет из расчётов. В оплату включены только 11-часовые смены (День 1, День 2, Ночь 1, Ночь 2).',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF2c3e50),
          fontWeight: FontWeight.bold,
          fontSize: 15.2,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Калькулятор зарплаты',
            style: TextStyle(
              fontSize: 20.8,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 20),
          _buildFormGroup('Оклад (руб.):', _okladController),
          _buildFormGroup(
              'Отработанные часы:', TextEditingController(text: _totalHours.toFixed(2)),
              isReadOnly: true),
          _buildFormGroup(
              'Ночные часы:', TextEditingController(text: _nightHours.toFixed(2)),
              isReadOnly: true),
          _buildFormGroup('Премия за месяц (%):', _premiumController),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _calculateSalary,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ).copyWith(
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              padding: MaterialStateProperty.all(const EdgeInsets.all(14)),
              textStyle: MaterialStateProperty.all(
                  const TextStyle(fontSize: 17.6, fontWeight: FontWeight.bold)),
              minimumSize:
                  MaterialStateProperty.all(const Size.fromHeight(50)),
              surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF27ae60), Color(0xFF2ecc71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                alignment: Alignment.center,
                child: const Text('Рассчитать зарплату',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          if (_salaryResult.isNotEmpty) _buildResultWidget(),
        ],
      ),
    );
  }

  Widget _buildFormGroup(String label, TextEditingController controller,
      {bool isReadOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF34495e),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType:
                isReadOnly ? TextInputType.none : TextInputType.number,
            readOnly: isReadOnly,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFced4da)),
              ),
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
            ),
            onChanged: (value) {
              // Пересчет статистики при изменении оклада или премии
              _calculateSalary();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildResultItem('Оклад:', _okladController.text, 'руб.'),
          _buildResultItem('Отработано часов:', _totalHours.toFixed(2), 'ч'),
          _buildResultItem('Премия:', _premiumController.text, '%'),
          const Divider(height: 30, thickness: 1, color: Color(0xFFdee2e6)),
          ..._salaryResult.split('---')[0].trim().split('\n').map((line) {
            final parts = line.split(':');
            return _buildResultItem(parts[0].trim(), parts[1].trim(), '');
          }).toList(),
          const Divider(height: 30, thickness: 2, color: Color(0xFFeeeeee)),
          Text(
            _salaryResult.split('**К ВЫПЛАТЕ:**')[1].trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22.4,
              fontWeight: FontWeight.bold,
              color: Color(0xFF27ae60),
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _okladController.text = '48910';
                _premiumController.text = '40';
                _salaryResult = '';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe0e0e0),
              foregroundColor: const Color(0xFF333333),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Новый расчёт',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value, String suffix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2c3e50),
            ),
          ),
          Text(
            '$value $suffix',
            style: TextStyle(
              color: label.contains('НДФЛ')
                  ? const Color(0xFFe74c3c)
                  : const Color(0xFF3498db),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF2c3e50),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Text(
        '© 2025 "Алексей Агафонов" - Расчет зарплаты',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.4,
        ),
      ),
    );
  }
}

// === Расширения для удобства ===

extension DoubleExtension on double {
  String toFixed(int fractionDigits) {
    return toStringAsFixed(fractionDigits);
  }
}
