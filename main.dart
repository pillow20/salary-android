import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() {
  // Убедитесь, что вы используете flutter run или перезапустили приложение полностью
  runApp(const SalaryCalculatorApp());
}

// ====================================================================
// DATA_MODEL (ChangeNotifier)
// ====================================================================
class SalaryCalculatorModel extends ChangeNotifier {
  // Input fields
  double _oklad; // Оклад
  double _hours; // Отработано часов
  double _nightHours; // Ночные часы
  double _premiumPercent; // Процент премии

  // Constants
  static const double _baseHours = 164.3333;
  static const double _nightRate = 0.4; // 40%
  static const double _harmRate = 0.04; // 4%
  static const double _ndflRate = 0.13; // 13%

  // Calculated fields
  double _baseRate = 0.0;
  double _basePay = 0.0;
  double _premiumPay = 0.0;
  double _nightPay = 0.0;
  double _totalBeforeHarm = 0.0;
  double _harmAddition = 0.0;
  double _totalWithHarm = 0.0;
  double _ndfl = 0.0;
  double _finalSalary = 0.0;

  SalaryCalculatorModel()
      : _oklad = 48910.0,
        _hours = 167.29,
        _nightHours = 57.03,
        _premiumPercent = 40.0 {
    _calculate(); // Initial calculation
  }

  // Getters for inputs
  double get oklad => _oklad;
  double get hours => _hours;
  double get nightHours => _nightHours;
  double get premiumPercent => _premiumPercent;

  // Getters for calculated results
  double get baseRate => _baseRate;
  double get basePay => _basePay;
  double get premiumPay => _premiumPay;
  double get nightPay => _nightPay;
  double get totalBeforeHarm => _totalBeforeHarm;
  double get harmAddition => _harmAddition;
  double get totalWithHarm => _totalWithHarm;
  double get ndfl => _ndfl;
  double get finalSalary => _finalSalary;

  // Setters for inputs, triggering recalculation
  void setOklad(String value) {
    _oklad = double.tryParse(value.replaceAll(',', '.')) ?? 0.0; // Обработка запятых
    _calculate();
  }

  void setHours(String value) {
    _hours = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
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
  
  // Функция для округления до двух знаков после запятой
  double _round(double value) {
    return (value * 100).round() / 100.0;
  }

  void _calculate() {
    if (_baseHours == 0) {
      _baseRate = 0.0;
    } else {
      _baseRate = _round(_oklad / _baseHours);
    }

    _basePay = _round(_baseRate * _hours);
    _premiumPay = _round(_basePay * (_premiumPercent / 100));
    _nightPay = _round(_baseRate * _nightHours * _nightRate);
    _totalBeforeHarm = _round(_basePay + _premiumPay + _nightPay);
    _harmAddition = _round(_totalBeforeHarm * _harmRate);
    _totalWithHarm = _round(_totalBeforeHarm + _harmAddition);
    _ndfl = _round(_totalWithHarm * _ndflRate);
    _finalSalary = _round(_totalWithHarm - _ndfl);

    notifyListeners();
  }

  // Возвращает true при сбросе
  bool reset() {
    _oklad = 48910.0;
    _hours = 167.29;
    _nightHours = 57.03;
    _premiumPercent = 40.0;
    _calculate();
    // Возвращаем true, чтобы _ResultDisplay знал, что нужно сбросить UI.
    return true; 
  }
}

// ====================================================================
// MAIN APP STRUCTURE
// ====================================================================

class SalaryCalculatorApp extends StatelessWidget {
  const SalaryCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SalaryCalculatorModel>(
      create: (BuildContext context) => SalaryCalculatorModel(),
      builder: (BuildContext context, Widget? child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Arial',
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
  late final TextEditingController _okladController;
  late final TextEditingController _hoursController;
  late final TextEditingController _nightHoursController;
  late final TextEditingController _premiumPercentController;
  
  // Создаем глобальный ключ для доступа к методу сброса в _ResultDisplay
  final GlobalKey<_ResultDisplayState> _resultDisplayKey = GlobalKey<_ResultDisplayState>();

  @override
  void initState() {
    super.initState();
    // Получаем начальные значения, чтобы заполнить контроллеры
    final SalaryCalculatorModel model = Provider.of<SalaryCalculatorModel>(context, listen: false);

    // !!! ИСПРАВЛЕНИЕ: Инициализируем контроллеры начальными значениями модели.
    // Т.к. модель НЕ слушается здесь, ввод не будет перезаписываться при каждом изменении.
    _okladController = TextEditingController(text: model.oklad.toStringAsFixed(2));
    _hoursController = TextEditingController(text: model.hours.toStringAsFixed(2));
    _nightHoursController = TextEditingController(text: model.nightHours.toStringAsFixed(2));
    _premiumPercentController = TextEditingController(text: model.premiumPercent.toStringAsFixed(1));
    
    // Курсор должен быть в конце для удобства
    _okladController.selection = TextSelection.fromPosition(TextPosition(offset: _okladController.text.length));
  }

  @override
  void dispose() {
    _okladController.dispose();
    _hoursController.dispose();
    _nightHoursController.dispose();
    _premiumPercentController.dispose();
    super.dispose();
  }
  
  // Метод для вызова сброса в модели и в UI
  void _resetApp() {
    final model = Provider.of<SalaryCalculatorModel>(context, listen: false);
    
    // 1. Сбрасываем модель и получаем новые дефолтные значения
    model.reset(); 

    // 2. Обновляем контроллеры новыми дефолтными значениями
    _okladController.text = model.oklad.toStringAsFixed(2);
    _hoursController.text = model.hours.toStringAsFixed(2);
    _nightHoursController.text = model.nightHours.toStringAsFixed(2);
    _premiumPercentController.text = model.premiumPercent.toStringAsFixed(1);
    
    // 3. Сбрасываем локальное состояние UI в виджете результатов
    _resultDisplayKey.currentState?._handleReset();
    
    // Снова устанавливаем курсор
    _okladController.selection = TextSelection.fromPosition(TextPosition(offset: _okladController.text.length));
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
                      _MainContentWidget(
                        okladController: _okladController,
                        hoursController: _hoursController,
                        nightHoursController: _nightHoursController,
                        premiumPercentController: _premiumPercentController,
                        resultDisplayKey: _resultDisplayKey, // Передаем ключ
                        resetCallback: _resetApp, // Передаем колбэк для сброса
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
// WIDGETS
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
            style: TextStyle(
              color: Colors.white,
              fontSize: Theme.of(context).textTheme.headlineSmall!.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10.0),
          Text(
            'Расчет вашей заработной платы',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: Theme.of(context).textTheme.titleLarge!.fontSize,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainContentWidget extends StatelessWidget {
  final TextEditingController okladController;
  final TextEditingController hoursController;
  final TextEditingController nightHoursController;
  final TextEditingController premiumPercentController;
  final GlobalKey<_ResultDisplayState> resultDisplayKey;
  final VoidCallback resetCallback;


  const _MainContentWidget({
    required this.okladController,
    required this.hoursController,
    required this.nightHoursController,
    required this.premiumPercentController,
    required this.resultDisplayKey,
    required this.resetCallback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
      child: Column(
        children: <Widget>[
          _SalaryForm(
            okladController: okladController,
            hoursController: hoursController,
            nightHoursController: nightHoursController,
            premiumPercentController: premiumPercentController,
          ),
          _ResultDisplay(
            key: resultDisplayKey,
            resetCallback: resetCallback,
          ),
        ],
      ),
    );
  }
}

class _SalaryForm extends StatelessWidget {
  final TextEditingController okladController;
  final TextEditingController hoursController;
  final TextEditingController nightHoursController;
  final TextEditingController premiumPercentController;

  const _SalaryForm({
    required this.okladController,
    required this.hoursController,
    required this.nightHoursController,
    required this.premiumPercentController,
  });

  @override
  Widget build(BuildContext context) {
    // Get model instance without listening to changes
    final SalaryCalculatorModel model = Provider.of<SalaryCalculatorModel>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FormGroup(
          label: 'Оклад (руб)',
          controller: okladController,
          keyboardType: TextInputType.number,
          onChanged: model.setOklad,
        ),
        const SizedBox(height: 20.0),
        _FormGroup(
          label: 'Отработано часов (ч)',
          controller: hoursController,
          keyboardType: TextInputType.number,
          onChanged: model.setHours,
        ),
        const SizedBox(height: 20.0),
        _FormGroup(
          label: 'Ночные часы (ч)',
          controller: nightHoursController,
          keyboardType: TextInputType.number,
          onChanged: model.setNightHours,
        ),
        const SizedBox(height: 20.0),
        _FormGroup(
          label: 'Премия (%)',
          controller: premiumPercentController,
          keyboardType: TextInputType.number,
          onChanged: model.setPremiumPercent,
        ),
      ],
    );
  }
}

class _FormGroup extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  const _FormGroup({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          keyboardType: keyboardType,
          // Разрешаем цифры, точку и запятую
          inputFormatters: keyboardType == TextInputType.number
              ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*$'))]
              : null,
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
    );
  }
}

// ====================================================================
// RESULT DISPLAY
// ====================================================================

class _ResultDisplay extends StatefulWidget {
  // Добавляем колбэк для сброса, который вызывает _resetApp в SalaryCalculatorScreenState
  final VoidCallback resetCallback;

  const _ResultDisplay({super.key, required this.resetCallback});

  @override
  State<_ResultDisplay> createState() => _ResultDisplayState();
}

class _ResultDisplayState extends State<_ResultDisplay> {
  // Локальное состояние для управления видимостью результатов
  bool _isCalculated = false;

  String _formatRubles(double amount) {
    return '${amount.toStringAsFixed(2)} руб.';
  }

  String _formatHours(double amount) {
    return '${amount.toStringAsFixed(2)} ч';
  }

  String _formatPercent(double amount) {
    return '${amount.toStringAsFixed(1)}%';
  }

  // Метод, который вызывается при нажатии кнопки "Рассчитать"
  void _calculateAndShow() {
    // !!! ИСПРАВЛЕНИЕ: Переключаем локальное состояние, чтобы открыть результаты
    setState(() {
      _isCalculated = true;
    });
  }
  
  // !!! ИСПРАВЛЕНИЕ: Метод, вызываемый извне (из _SalaryCalculatorScreenState._resetApp)
  void _handleReset() {
    setState(() {
      _isCalculated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Используем Provider.of для реактивного отображения данных (listen: true по умолчанию)
    final SalaryCalculatorModel model = Provider.of<SalaryCalculatorModel>(context);

    if (!_isCalculated) {
      // Кнопка "Рассчитать"
      return Padding(
        padding: const EdgeInsets.only(top: 25.0),
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
              label: 'Отработано часов:', value: _formatHours(model.hours)),
          _ResultItem(
              label: 'Ночные часы:', value: _formatHours(model.nightHours)),
          _ResultItem(
              label: 'Премия:', value: _formatPercent(model.premiumPercent)),
          const Divider(height: 40.0, thickness: 1.0, color: Color(0xFFdee2e6)),
          _ResultItem(
              label: 'Ставка за час:', value: _formatRubles(model.baseRate)),
          _ResultItem(
              label: '1. Основная оплата:', value: _formatRubles(model.basePay)),
          _ResultItem(
              label: '2. Премия:', value: _formatRubles(model.premiumPay)),
          _ResultItem(
              label: '3. Доплата за ночные часы:',
              value: _formatRubles(model.nightPay)),
          _ResultItem(
              label: '4. Итого до вредности:',
              value: _formatRubles(model.totalBeforeHarm)),
          _ResultItem(
              label: '5. Доплата за вредность (4%):',
              value: _formatRubles(model.harmAddition)),
          _ResultItem(
              label: '6. Итого до НДФЛ:',
              value: _formatRubles(model.totalWithHarm)),
          _ResultItem(
            label: '7. НДФЛ (13%):',
            value: '-${_formatRubles(model.ndfl)}',
            valueColor: const Color(0xFFe74c3c),
          ),
          const SizedBox(height: 10.0),
          _TotalAmountDisplay(
              label: 'К ВЫПЛАТЕ:',
              amount: _formatRubles(model.finalSalary)),
          const SizedBox(height: 20.0),
          // Используем колбэк для сброса всего приложения
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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              children: <Widget>[
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 5.0),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? const Color(0xFF2c3e50),
                  ),
                ),
              ],
            );
          } else {
            return Row(
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
            );
          }
        },
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

class _CalculateButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CalculateButton({required this.onPressed});

  @override
  State<_CalculateButton> createState() => _CalculateButtonState();
}

class _CalculateButtonState extends State<_CalculateButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _isPressed ? 0 : -2, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF3498db), Color(0xFF2980b9)], // Синий градиент
          ),
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15.0),
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
    );
  }
}

class _ResetButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ResetButton({required this.onPressed});

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _isPressed ? 0 : -2, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF95a5a6), Color(0xFF7f8c8d)],
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.all(15.0),
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