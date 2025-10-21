import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const SalaryCalculatorApp());
}

// ====================================================================
// 1. DATA MODEL (SalaryCalculatorModel) - ЛОГИКА РАСЧЕТОВ
// ====================================================================

class SalaryCalculatorModel extends ChangeNotifier {
  // Исходные значения из JS
  double _oklad = 48910.0;
  double _weekendHours = 11.0;
  double _nightHours = 7.5;
  double _premiumPercent = 40.0;

  // Константы из JS
  static const double _baseHours = 164.3333; // Норма часов в месяце
  static const double _nightRate = 0.4;      // +40% за ночные
  static const double _ndflRate = 0.13;      // 13% НДФЛ

  // Результаты расчетов
  double _baseRate = 0.0;
  double _weekendPay = 0.0;
  double _nightPay = 0.0;
  double _premiumPay = 0.0;
  double _totalBeforePremium = 0.0;
  double _totalBeforeTax = 0.0;
  double _ndfl = 0.0;
  double _finalSalary = 0.0;

  SalaryCalculatorModel() {
    _calculate(); // Инициализация
  }

  // Геттеры для доступа к данным
  double get oklad => _oklad;
  double get weekendHours => _weekendHours;
  double get nightHours => _nightHours;
  double get premiumPercent => _premiumPercent;

  double get baseRate => _baseRate;
  double get weekendPay => _weekendPay;
  double get nightPay => _nightPay;
  double get premiumPay => _premiumPay;
  double get totalBeforePremium => _totalBeforePremium;
  double get totalBeforeTax => _totalBeforeTax;
  double get ndfl => _ndfl;
  double get finalSalary => _finalSalary;

  // Функция для округления до двух знаков после запятой (бухгалтерская точность)
  double _round(double value) {
    return (value * 100).round() / 100.0;
  }

  // Сеттеры для полей ввода (автоматически запускают перерасчет)
  void setOklad(String value) {
    _oklad = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    _calculate();
  }

  void setWeekendHours(String value) {
    _weekendHours = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    _calculate();
  }

  void setNightHours(String value) {
    _nightHours = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    _calculate();
  }

  void setPremiumPercent(String value) {
    _premiumPercent = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    _calculate();
  }

  // ЛОГИКА РАСЧЕТА (повторяет JS-код)
  void _calculate() {
    // Часовая ставка
    _baseRate = _baseHours == 0 ? 0.0 : _round(_oklad / _baseHours);

    // 1. Оплата за выходные часы (в двойном размере)
    _weekendPay = _round(_baseRate * _weekendHours * 2);

    // 2. Доплата за ночные часы (+40% от ставки)
    _nightPay = _round(_baseRate * _nightHours * _nightRate);

    // 3. Итого до премии
    _totalBeforePremium = _round(_weekendPay + _nightPay);

    // 4. Премия (в % от суммы до премии)
    _premiumPay = _round(_totalBeforePremium * (_premiumPercent / 100));

    // 5. Итого до НДФЛ
    _totalBeforeTax = _round(_totalBeforePremium + _premiumPay);

    // 6. НДФЛ (13%)
    _ndfl = _round(_totalBeforeTax * _ndflRate);

    // 7. К выплате
    _finalSalary = _round(_totalBeforeTax - _ndfl);

    notifyListeners();
  }

  // Сброс к дефолтным значениям
  void reset() {
    _oklad = 48910.0;
    _weekendHours = 11.0;
    _nightHours = 7.5;
    _premiumPercent = 40.0;
    _calculate();
  }
}

// ====================================================================
// 2. MAIN APP AND SCREEN
// ====================================================================

class SalaryCalculatorApp extends StatelessWidget {
  const SalaryCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Оборачиваем в Provider для управления состоянием
    return ChangeNotifierProvider<SalaryCalculatorModel>(
      create: (BuildContext context) => SalaryCalculatorModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Arial',
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const SalaryCalculatorScreen(),
      ),
    );
  }
}

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  // Контроллеры для полей ввода
  late final TextEditingController _okladController;
  late final TextEditingController _weekendHoursController;
  late final TextEditingController _nightHoursController;
  late final TextEditingController _premiumPercentController;

  // Глобальный ключ для доступа к состоянию _ResultDisplay
  final GlobalKey<_ResultDisplayState> _resultDisplayKey = GlobalKey<_ResultDisplayState>();

  @override
  void initState() {
    super.initState();
    final model = Provider.of<SalaryCalculatorModel>(context, listen: false);

    // Инициализируем контроллеры начальными значениями модели
    _okladController = TextEditingController(text: model.oklad.toStringAsFixed(0));
    _weekendHoursController = TextEditingController(text: model.weekendHours.toStringAsFixed(1));
    _nightHoursController = TextEditingController(text: model.nightHours.toStringAsFixed(1));
    _premiumPercentController = TextEditingController(text: model.premiumPercent.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _okladController.dispose();
    _weekendHoursController.dispose();
    _nightHoursController.dispose();
    _premiumPercentController.dispose();
    super.dispose();
  }

  // Единый метод для сброса состояния (модели и UI)
  void _resetApp() {
    final model = Provider.of<SalaryCalculatorModel>(context, listen: false);

    // 1. Сброс модели
    model.reset();

    // 2. Обновление текста контроллеров
    _okladController.text = model.oklad.toStringAsFixed(0);
    _weekendHoursController.text = model.weekendHours.toStringAsFixed(1);
    _nightHoursController.text = model.nightHours.toStringAsFixed(1);
    _premiumPercentController.text = model.premiumPercent.toStringAsFixed(0);

    // 3. Сброс локального состояния UI (скрываем результаты)
    _resultDisplayKey.currentState?._handleReset();
    
    // Перемещаем фокус (для скрытия клавиатуры и удобства)
    FocusScope.of(context).requestFocus(FocusNode());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.1),
                        offset: Offset(0, 20),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      const _HeaderWidget(),
                      Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          children: <Widget>[
                            _SalaryForm(
                              okladController: _okladController,
                              weekendHoursController: _weekendHoursController,
                              nightHoursController: _nightHoursController,
                              premiumPercentController: _premiumPercentController,
                            ),
                            _ResultDisplay(
                              key: _resultDisplayKey,
                              resetCallback: _resetApp,
                            ),
                          ],
                        ),
                      ),
                      const _FooterWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// 3. WIDGETS
// ====================================================================

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2c3e50), Color(0xFF3498db)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
      child: Column(
        children: <Widget>[
          Text(
            'Калькулятор Зарплаты',
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10.0),
          Text(
            'Расчет вашей заработной платы',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryForm extends StatelessWidget {
  final TextEditingController okladController;
  final TextEditingController weekendHoursController;
  final TextEditingController nightHoursController;
  final TextEditingController premiumPercentController;

  const _SalaryForm({
    required this.okladController,
    required this.weekendHoursController,
    required this.nightHoursController,
    required this.premiumPercentController,
  });

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<SalaryCalculatorModel>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FormGroup(
          label: 'Оклад (руб)',
          controller: okladController,
          onChanged: model.setOklad,
        ),
        _FormGroup(
          label: 'Часы в выходной/праздничный день (ч)',
          controller: weekendHoursController,
          onChanged: model.setWeekendHours,
        ),
        _FormGroup(
          label: 'Ночные часы (ч)',
          controller: nightHoursController,
          onChanged: model.setNightHours,
        ),
        _FormGroup(
          label: 'Процент премии (%)',
          controller: premiumPercentController,
          onChanged: model.setPremiumPercent,
        ),
      ],
    );
  }
}

class _FormGroup extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _FormGroup({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2c3e50),
              fontSize: 18.0,
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Разрешаем цифры, точку и запятую
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*$')),
            ],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Color(0xFFe1e8ed), width: 2.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Color(0xFFe1e8ed), width: 2.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Color(0xFF3498db), width: 2.0),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            style: const TextStyle(fontSize: 18.0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 4. RESULT DISPLAY
// ====================================================================

class _ResultDisplay extends StatefulWidget {
  final VoidCallback resetCallback;

  const _ResultDisplay({super.key, required this.resetCallback});

  @override
  State<_ResultDisplay> createState() => _ResultDisplayState();
}

class _ResultDisplayState extends State<_ResultDisplay> {
  // Локальное состояние для управления видимостью результатов
  bool _isCalculated = false;

  String _formatRubles(double amount, {int fractionDigits = 2}) {
    return '${amount.toStringAsFixed(fractionDigits)} руб.';
  }

  String _formatHours(double amount) {
    return '${amount.toStringAsFixed(2)} ч';
  }

  String _formatPercent(double amount) {
    return '${amount.toStringAsFixed(1)}%';
  }

  // Метод, который вызывается при нажатии кнопки "Рассчитать"
  void _calculateAndShow() {
    // Выполняем расчет (он уже происходит в onChanged, но вызываем для уверенности)
    Provider.of<SalaryCalculatorModel>(context, listen: false)._calculate();
    
    // Показываем блок результатов
    setState(() {
      _isCalculated = true;
    });

    // Прокрутка к результатам
    Future.delayed(const Duration(milliseconds: 50), () {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0,
      );
    });
  }

  // Метод, вызываемый извне для сброса UI
  void _handleReset() {
    setState(() {
      _isCalculated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем модель, чтобы результаты обновлялись
    final model = context.watch<SalaryCalculatorModel>();

    if (!_isCalculated) {
      // Кнопка "Рассчитать"
      return Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: _CalculateButton(onPressed: _calculateAndShow),
      );
    }

    // Блок результатов
    return Container(
      margin: const EdgeInsets.only(top: 25.0),
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: const Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(10.0),
        border: const Border(
          left: BorderSide(color: Color(0xFF3498db), width: 5.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Результаты расчета',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF2c3e50),
              fontSize: 22.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20.0),
          _ResultItem(
              label: 'Оклад:', value: _formatRubles(model.oklad)),
          _ResultItem(
              label: 'Часы в выходной:', value: _formatHours(model.weekendHours)),
          _ResultItem(
              label: 'Ночные часы:', value: _formatHours(model.nightHours)),
          _ResultItem(
              label: 'Премия:', value: _formatPercent(model.premiumPercent)),
          const Divider(height: 40.0, thickness: 1.0, color: Color(0xFFdee2e6)),
          _ResultItem(
              label: 'Ставка за час:', value: _formatRubles(model.baseRate)),
          _ResultItem(
              label: '1. Оплата в выходной (×2):', value: _formatRubles(model.weekendPay)),
          _ResultItem(
              label: '2. Доплата за ночные часы (+40%):', value: _formatRubles(model.nightPay)),
          _ResultItem(
              label: '3. Итого до премии:',
              value: _formatRubles(model.totalBeforePremium)),
          _ResultItem(
              label: '4. Премия:', value: _formatRubles(model.premiumPay)),
          _ResultItem(
              label: '5. Итого до НДФЛ:',
              value: _formatRubles(model.totalBeforeTax)),
          _ResultItem(
            label: '6. НДФЛ (13%):',
            value: '-${_formatRubles(model.ndfl)}',
            valueColor: const Color(0xFFe74c3c),
          ),
          const SizedBox(height: 10.0),
          _TotalAmountDisplay(
              label: 'К ВЫПЛАТЕ:',
              amount: _formatRubles(model.finalSalary)),
          const SizedBox(height: 20.0),
          // Кнопка сброса, которая вызывает _resetApp в главном стейте
          _ResetButton(onPressed: widget.resetCallback),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFe9ecef), width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF495057),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF2c3e50),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalAmountDisplay extends StatelessWidget {
  final String label;
  final String amount;

  const _TotalAmountDisplay({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(39, 174, 96, 0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18.0,
              color: Color(0xFF27ae60),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            amount,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22.4,
              color: Color(0xFF27ae60),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculateButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CalculateButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(18.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent, 
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.3),
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) {
              return const Color(0xFF2980b9); 
            }
            return const Color(0xFF3498db); 
          },
        ),
        elevation: MaterialStateProperty.resolveWith<double>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) {
              return 0; 
            }
            return 5;
          },
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF3498db), Color(0xFF2980b9)],
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50.0),
          alignment: Alignment.center,
          child: const Text(
            'Рассчитать зарплату',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}


class _ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent, 
        elevation: 0,
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) {
              return const Color(0xFF7f8c8d); 
            }
            return const Color(0xFF95a5a6); 
          },
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF95a5a6), Color(0xFF7f8c8d)],
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40.0),
          alignment: Alignment.center,
          child: const Text(
            'Сбросить',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterWidget extends StatelessWidget {
  const _FooterWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2c3e50),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15.0)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: const Text(
        '© 2023 Калькулятор Зарплаты. Все права защищены.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.4,
        ),
      ),
    );
  }
}