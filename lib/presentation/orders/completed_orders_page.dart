import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../home/drawer/app_drawer.dart';

class CompletedOrdersPage extends StatefulWidget {
  const CompletedOrdersPage({super.key});

  @override
  State<CompletedOrdersPage> createState() => _CompletedOrdersPageState();
}

class _CompletedOrdersPageState extends State<CompletedOrdersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<OrderItem> _orders = [];
  List<OrderItem> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    // Datos mock - En producción vendrían de una API
    _orders = [
      OrderItem(
        folio: '0001',
        razonSocial: 'Proveedores SA de CV',
        fecha: '01-Enero-2026',
        color: AppColors.primaryBlue,
      ),
      OrderItem(
        folio: '0002',
        razonSocial: 'Proveedores SA de CV',
        fecha: '01-Enero-2026',
        color: AppColors.primaryRed,
      ),
      OrderItem(
        folio: '0003',
        razonSocial: 'Proveedores SA de CV',
        fecha: '01-Enero-2026',
        color: AppColors.primaryBlue,
      ),
      OrderItem(
        folio: '0004',
        razonSocial: 'Proveedores SA de CV',
        fecha: '01-Enero-2026',
        color: AppColors.primaryRed,
      ),
    ];
    _filteredOrders = _orders;
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((order) {
          return order.razonSocial.toLowerCase().contains(query) ||
              order.folio.toLowerCase().contains(query) ||
              order.fecha.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: const Text(
          'Órdenes Realizadas',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSearchBar(),
          ),
          // Lista de órdenes
          Expanded(
            child: _filteredOrders.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron órdenes',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(_filteredOrders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textFieldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Realizar búsqueda...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.textFieldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: order.color,
          child: const Icon(
            Icons.calendar_today,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          'Razón Social: ${order.razonSocial}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            order.fecha,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Folio:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            Text(
              order.folio,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navegar a detalle de orden
        },
      ),
    );
  }
}

class OrderItem {
  final String folio;
  final String razonSocial;
  final String fecha;
  final Color color;

  OrderItem({
    required this.folio,
    required this.razonSocial,
    required this.fecha,
    required this.color,
  });
}
