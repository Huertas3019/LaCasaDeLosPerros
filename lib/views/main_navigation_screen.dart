import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'pos/pos_screen.dart';
import 'inventario/inventario_screen.dart';
import 'turnos/turnos_screen.dart';
import 'gastos/gastos_screen.dart';
import 'balance/balance_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Key> _tabKeys = List.generate(5, (_) => UniqueKey());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.jpeg',
              height: 36,
              width: 36,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'LA CASA DE LOS PERROS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                Text(
                  'Sistema POS & Inventario',
                  style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar vista',
            onPressed: () {
              setState(() {
                _tabKeys[_currentIndex] = UniqueKey();
              });
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PosScreen(key: _tabKeys[0]),
          InventarioScreen(key: _tabKeys[1]),
          TurnosScreen(key: _tabKeys[2]),
          GastosScreen(key: _tabKeys[3]),
          BalanceScreen(key: _tabKeys[4]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _tabKeys[index] = UniqueKey();
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'POS Vender',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_filled),
            label: 'Caja & Turnos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Gastos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Balance & Backup',
          ),
        ],
      ),
    );
  }
}
