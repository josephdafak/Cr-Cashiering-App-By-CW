import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('cashierBox'); // Stores current day's records
  await Hive.openBox('incomeDataBox'); // Stores aggregated income data by date
  await Hive.openBox('historicalRecordsBox'); // Stores historical records
  await Hive.openBox('settingsBox'); // Stores price settings and last cleared date
  runApp(CashieringApp());
}

class CashieringApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: const Color.fromARGB(255, 0, 0, 0),
        scaffoldBackgroundColor: Colors.white,
      ),
      title: 'CR Cashiering App',
      home: CashieringHomePage(),
    );
  }
}

class CashieringHomePage extends StatefulWidget {
  @override
  _CashieringHomePageState createState() => _CashieringHomePageState();
}

class _CashieringHomePageState extends State<CashieringHomePage> {
  final Box cashierBox = Hive.box('cashierBox');
  final Box incomeDataBox = Hive.box('incomeDataBox');
  final Box historicalRecordsBox = Hive.box('historicalRecordsBox');
  final Box settingsBox = Hive.box('settingsBox');
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _checkAndClearRecordsForNewDay();
  }

  void _checkAndClearRecordsForNewDay() {
    final now = DateTime.now();
    final lastClearedDate = settingsBox.get('lastClearedDate', defaultValue: '');

    final todayDate = DateFormat('yyyy-MM-dd').format(now);

    if (lastClearedDate != todayDate) {
      // A new day has started
      _moveRecordsToHistoricalBox();
      _moveDailyIncomeToSeparateRecord();
      cashierBox.clear(); // Clear cashier records
      settingsBox.put('lastClearedDate', todayDate); // Update last cleared date
    }
  }

  void _moveRecordsToHistoricalBox() {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);

    // Move all records from cashierBox to historicalRecordsBox
    final records = cashierBox.values.toList();
    for (var record in records) {
      historicalRecordsBox.add({
        ...record,
        'date': dateKey, // Ensure the date is stored correctly
      });
    }
  }

  void _moveDailyIncomeToSeparateRecord() {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);

    // Calculate total income for the day
    double dailyIncome = cashierBox.values.fold(0.0, (sum, record) {
      if (record is Map && record.containsKey('amount')) {
        return sum + (record['amount'] ?? 0.0);
      }
      return sum;
    });

    // Store daily income in incomeDataBox
    if (dailyIncome > 0) {
      incomeDataBox.put(dateKey, dailyIncome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CR Cashiering App'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(settingsBox),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: AssetImage('assets/images/logo.png'),
                ),
                SizedBox(width: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: AssetImage('assets/images/logo2.jpg'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton('Tae', settingsBox.get('Tae', defaultValue: 10.0)),
                _buildButton('Ihi', settingsBox.get('Ihi', defaultValue: 5.0)),
                _buildButton('Ligo', settingsBox.get('Ligo', defaultValue: 20.0)),
              ],
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: cashierBox.listenable(),
                builder: (context, Box box, _) {
                  List records = box.values.toList().reversed.toList();
                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Dismissible(
                        key: Key(record['date']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete,
                            color: const Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                        secondaryBackground: Container(
                          color: const Color.fromARGB(255, 1, 139, 252),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: 20),
                          child: Icon(Icons.edit, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            return await _showDeleteConfirmationDialog(record);
                          } else if (direction == DismissDirection.startToEnd) {
                            await _showEditDialog(record);
                            return false;
                          }
                          return false;
                        },
                        onDismissed: (direction) {
                          // Handle dismissal
                        },
                        child: ListTile(
                          title: Text(
                            '${record['type']} - ₱${record['amount'].toInt()}',
                          ),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(record['date'])),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: const Color.fromARGB(255, 228, 0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: _showIncomeDialog,
              child: Text(
                'View Income',
                style: TextStyle(
                  color: const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120, // Adjusted height for better fit
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 0, 0),
            ),
            child: Center(
              child: Text(
                'CR Cashiering App',
                style: TextStyle(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontSize: 24,
                ),
              ),
            ),
          ),
          ListTile(
            title: Text('How to Use the App'),
            onTap: () {
              Navigator.pop(context);
              _showHowToUseDialog();
            },
          ),
          ListTile(
            title: Text('About Us'),
            onTap: () {
              Navigator.pop(context);
              _showAboutUsDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showHowToUseDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('How to Use the App'),
          content: Text(
            '1. Choose one from Tae, Ihi, or Ligo, along with their prices.\n'
            '2. If you accidentally click a button, just swipe left to delete the record.\n'
            '3. If you want to change the price, click the Settings icon.\n'
            '4. To view income, select a date range and a category (Tae, Ihi, Ligo, or All), then click "View Income" to see the total earnings.\n',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutUsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('About Us'),
          content: Text(
            'We, Joseph Carvajal and Derrick Gabrielle Waniwan, created this app to make income tracking easier and more efficient.\n\n'
            'Our goal is to provide a simple and user-friendly tool for managing and viewing income records. We hope this app helps you stay organized and saves you time!\n\n'
            'Thank you for using our app!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButton(String text, double amount) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 248, 0, 0),
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        _addCashierRecord(text, amount);
        setState(() {});
      },
      child: Text('$text (₱${amount.toInt()})'),
    );
  }

  void _addCashierRecord(String type, double amount) {
    final record = {
      'type': type,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
    };
    cashierBox.add(record);
  }

  void _showIncomeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the dialog to be scrollable
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.6, // Adjusted height
              child: Column(
                children: [
                  // Date Range Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _fromDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              _fromDate = picked;
                            });
                          }
                        },
                        child: Text(
                          _fromDate == null
                              ? 'FROM'
                              : DateFormat('M/d/yyyy').format(_fromDate!),
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _toDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              _toDate = picked;
                            });
                          }
                        },
                        child: Text(
                          _toDate == null
                              ? 'TO'
                              : DateFormat('M/d/yyyy').format(_toDate!),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  if (_fromDate != null && _toDate != null)
                    Text(
                      '${DateFormat('M/d/yyyy').format(_fromDate!)} - ${DateFormat('M/d/yyyy').format(_toDate!)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 20),

                  // Category Dropdown
                  DropdownButton<String>(
                    value: _selectedCategory,
                    hint: Text('Select Category'),
                    items: ['Ihi', 'Tae', 'Ligo', 'All'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setModalState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  if (_selectedCategory != null)
                    Text(
                      'Selected Category: $_selectedCategory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 20),

                  // Income Details
                  if (_fromDate != null && _toDate != null && _selectedCategory != null)
                    _buildIncomeDetails(),

                  // Clear and Close Buttons
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            _fromDate = null;
                            _toDate = null;
                            _selectedCategory = null;
                          });
                        },
                        child: Text('Clear'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('Close'),
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

  Widget _buildIncomeDetails() {
    if (_fromDate == null || _toDate == null || _selectedCategory == null) {
      return SizedBox.shrink(); // Hide if no category is selected
    }

    double totalIncome = _calculateIncomeForRange(
      _fromDate!,
      _toDate!,
      _selectedCategory!,
    );

    return Column(
      children: [
        Text(
          'Total Income for $_selectedCategory',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        Text(
          '₱${totalIncome.toInt()}',
          style: TextStyle(fontSize: 24, color: Colors.green),
        ),
      ],
    );
  }

double _calculateIncomeForRange(
  DateTime fromDate,
  DateTime toDate,
  String category,
) {
  double totalIncome = 0.0;

  // Normalize the dates to the start of the day
  DateTime startDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
  DateTime endDate = DateTime(toDate.year, toDate.month, toDate.day + 1); // Start of the next day

  print('Calculating income from $startDate to $endDate for category: $category');

  // Calculate income from cashierBox (current day's records)
  if (startDate.isAtSameMomentAs(DateTime.now()) || 
      (startDate.isBefore(DateTime.now()) && endDate.isAfter(DateTime.now()))) {
    totalIncome += cashierBox.values.fold(0.0, (sum, record) {
      if (record is Map &&
          record.containsKey('date') &&
          record.containsKey('amount')) {
        DateTime recordDate = DateTime.parse(record['date']);
        print('CashierBox Record - Date: $recordDate, Type: ${record['type']}, Amount: ${record['amount']}');

        // Check if the record matches the selected category or "All"
        if (category == 'All' || record['type'] == category) {
          print('Including CashierBox Record: $record');
          return sum + (record['amount'] ?? 0.0);
        }
      }
      return sum;
    });
  }

  // Calculate income from historicalRecordsBox (past records)
  totalIncome += historicalRecordsBox.values.fold(0.0, (sum, record) {
    if (record is Map &&
        record.containsKey('date') &&
        record.containsKey('amount')) {
      DateTime recordDate = DateTime.parse(record['date']);
      print('HistoricalRecordBox Record - Date: $recordDate, Type: ${record['type']}, Amount: ${record['amount']}');

      // Check if the record is within the selected date range
      if (recordDate.isAtSameMomentAs(startDate) || 
          (recordDate.isAfter(startDate) && recordDate.isBefore(endDate))) {
        // Check if the record matches the selected category or "All"
        if (category == 'All' || record['type'] == category) {
          print('Including HistoricalRecordBox Record: $record');
          return sum + (record['amount'] ?? 0.0);
        }
      }
    }
    return sum;
  });

  print('Total Income: $totalIncome'); // Debug log
  return totalIncome;
}
  Future<bool?> _showDeleteConfirmationDialog(Map record) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Record'),
          content: Text('Are you sure you want to delete this record?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                cashierBox.deleteAt(cashierBox.values.toList().indexOf(record));
                Navigator.pop(context, true);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(Map record) async {
    TextEditingController typeController = TextEditingController(
      text: record['type'],
    );
    TextEditingController amountController = TextEditingController(
      text: record['amount'].toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Record'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Amount'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (typeController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  double amount =
                      double.tryParse(amountController.text) ??
                      record['amount'];
                  cashierBox.put(record['date'], {
                    'type': typeController.text,
                    'amount': amount,
                    'date': record['date'],
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Box settingsBox;
  SettingsPage(this.settingsBox);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController taeController = TextEditingController();
  TextEditingController ihiController = TextEditingController();
  TextEditingController ligoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    taeController.text =
        widget.settingsBox.get('Tae', defaultValue: 10.0).toInt().toString();
    ihiController.text =
        widget.settingsBox.get('Ihi', defaultValue: 5.0).toInt().toString();
    ligoController.text =
        widget.settingsBox.get('Ligo', defaultValue: 20.0).toInt().toString();
  }

  void _savePrices() {
    widget.settingsBox.put('Tae', double.tryParse(taeController.text) ?? 10.0);
    widget.settingsBox.put('Ihi', double.tryParse(ihiController.text) ?? 5.0);
    widget.settingsBox.put(
      'Ligo',
      double.tryParse(ligoController.text) ?? 20.0,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _buildPriceField('Tae', taeController),
              _buildPriceField('Ihi', ihiController),
              _buildPriceField('Ligo', ligoController),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _savePrices, child: Text('Save')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '$label Price'),
    );
  }
}