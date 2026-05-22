import 'package:flutter/material.dart';

class MonthSelectorWidget extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final Function(int year, int month) onMonthChanged;

  const MonthSelectorWidget({
    required this.initialYear,
    required this.initialMonth,
    required this.onMonthChanged,
    super.key,
  });

  @override
  State<MonthSelectorWidget> createState() => _MonthSelectorWidgetState();
}

class _MonthSelectorWidgetState extends State<MonthSelectorWidget> {
  late int _currentYear;
  late int _currentMonth;

  @override
  void initState() {
    _currentYear = widget.initialYear;
    _currentMonth = widget.initialMonth;
    super.initState();
  }

  bool _canGoForward() {
    final now = DateTime.now();
    return _currentYear < now.year ||
           (_currentYear == now.year && _currentMonth < now.month);
  }

  void _previousMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      widget.onMonthChanged(_currentYear, _currentMonth);
    });
  }

  void _nextMonth() {
    if (_canGoForward()) {
      setState(() {
        if (_currentMonth == 12) {
          _currentMonth = 1;
          _currentYear++;
        } else {
          _currentMonth++;
        }
        widget.onMonthChanged(_currentYear, _currentMonth);
      });
    }
  }

  void _showMonthPicker() {
    int tempYear = _currentYear;
    int tempMonth = _currentMonth;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de año
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setModalState(() => tempYear--),
                      ),
                      Text(
                        "$tempYear",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setModalState(() => tempYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Grid de meses
                  GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = tempMonth == monthNum && tempYear == _currentYear;
                      return GestureDetector(
                        onTap: () => setModalState(() => tempMonth = monthNum),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                              ? const Color(0xFF0F6E56)
                              : const Color(0xFFF8F9FA),
                            border: Border.all(
                              color: isSelected
                                ? const Color(0xFF0F6E56)
                                : const Color(0xFFE1E3E4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _getMonthAbbr(monthNum),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _currentYear = tempYear;
                              _currentMonth = tempMonth;
                            });
                            widget.onMonthChanged(tempYear, tempMonth);
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F6E56),
                          ),
                          child: const Text("Confirmar"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const names = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return names[month - 1];
  }

  String _getMonthAbbr(int month) {
    const abbr = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return abbr[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _getMonthName(_currentMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBEC9C3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF0F6E56)),
            onPressed: _previousMonth,
          ),
          InkWell(
            onTap: _showMonthPicker,
            child: Column(
              children: [
                Text(
                  monthName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191C1D),
                  ),
                ),
                Text(
                  "$_currentYear",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3F4944),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF0F6E56)),
            onPressed: _canGoForward() ? _nextMonth : null,
            disabledColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
