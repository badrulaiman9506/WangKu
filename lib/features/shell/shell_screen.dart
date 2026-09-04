import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wangku/core/theme/app_theme.dart';
import 'package:wangku/features/home/index.dart';
import 'package:wangku/features/expenses/index.dart';
import 'package:wangku/features/placeholder/index.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          ExpensesScreen(),
          PlaceholderScreen(),
          PlaceholderScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake),
            label: 'Debts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.target),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}