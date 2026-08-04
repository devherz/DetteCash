import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/commerce.dart';
import '../models/client.dart';
import 'add_client_screen.dart';
import 'client_detail_screen.dart';
import 'settings_screen.dart';

import '../models/user.dart';

class DashboardScreen extends StatefulWidget {
  final Commerce commerce;
  final UserModel? loggedUser;
  final VoidCallback? onLogout;
  final Function(UserModel)? onUserUpdated;

  const DashboardScreen({
    super.key,
    required this.commerce,
    this.loggedUser,
    this.onLogout,
    this.onUserUpdated,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Commerce _commerce;
  List<ClientBalanceInfo> _allClients = [];
  List<ClientBalanceInfo> _filteredClients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  double _totalDettes = 0.0;
  double _totalPaiements = 0.0;

  final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _commerce = widget.commerce;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh commerce data (in case it was updated)
      if (_commerce.id != null) {
        final updatedCommerce = await DatabaseHelper.instance.getCommerce(_commerce.id!);
        if (updatedCommerce != null) {
          _commerce = updatedCommerce;
        }

        final clients = await DatabaseHelper.instance.getClientsWithBalances(_commerce.id!);
        
        double d = 0;
        double p = 0;
        for (var c in clients) {
          d += c.totalDette;
          p += c.totalPaiement;
        }

        setState(() {
          _allClients = clients;
          _totalDettes = d;
          _totalPaiements = p;
          _filterClients(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des données : $e')),
        );
      }
    }
  }

  void _filterClients(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      setState(() {
        _filteredClients = List.from(_allClients);
      });
    } else {
      setState(() {
        _filteredClients = _allClients.where((clientInfo) {
          final nom = clientInfo.client.nomComplet.toLowerCase();
          final tel = clientInfo.client.telephone.toLowerCase();
          final q = query.toLowerCase();
          return nom.contains(q) || tel.contains(q);
        }).toList();
      });
    }
  }

  Future<void> _editCommerceProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          commerce: _commerce,
          loggedUser: widget.loggedUser,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );

    if (result == 'LOGOUT') {
      if (widget.onLogout != null) {
        widget.onLogout!();
      }
      return;
    }

    if (result == true || result is Commerce) {
      _loadData();
    }
  }

  Future<void> _navigateToAddClient() async {
    final bool? shouldReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddClientScreen(commerceId: _commerce.id!),
      ),
    );

    if (shouldReload == true) {
      _loadData();
    }
  }

  Future<void> _navigateToClientDetail(Client client) async {
    final bool? shouldReload = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailScreen(client: client, commerce: _commerce),
      ),
    );

    if (shouldReload == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final double soldeNetTotal = _totalDettes - _totalPaiements;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_commerce.logoPath != null) ...[
              CircleAvatar(
                radius: 18,
                backgroundImage: FileImage(File(_commerce.logoPath!)),
              ),
              const SizedBox(width: 10),
            ] else ...[
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.storefront, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _commerce.nomCommerce,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _commerce.telephoneCommerce,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres Boutique',
            onPressed: _editCommerceProfile,
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // KPI Dashboard Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor.withValues(alpha: 0.85), primaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'En-cours Total Débiteurs',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currencyFormatter.format(soldeNetTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(color: Colors.white30, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.arrow_upward, size: 14, color: Colors.amber),
                                        SizedBox(width: 4),
                                        Text('Dettes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormatter.format(_totalDettes),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.arrow_downward, size: 14, color: Colors.lightGreenAccent),
                                        SizedBox(width: 4),
                                        Text('Paiements', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormatter.format(_totalPaiements),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterClients,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un client...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterClients('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header of list
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vos Clients (${_filteredClients.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Solde dû',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Client List
                  _filteredClients.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isNotEmpty ? Icons.search_off_outlined : Icons.people_outline,
                                    size: 72,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'Aucun client ne correspond à la recherche' : 'Aucun client pour le moment',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Vérifiez l\'orthographe ou essayez un autre mot'
                                        : 'Appuyez sur le bouton + pour ajouter votre premier client débiteur.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderWithDetector(
                            (context, index) {
                              final clientInfo = _filteredClients[index];
                              final client = clientInfo.client;
                              final solde = clientInfo.solde;

                              Color balanceColor = Colors.grey[700]!;
                              String balancePrefix = '';
                              FontWeight balanceWeight = FontWeight.normal;

                              if (solde > 0) {
                                balanceColor = Colors.red[700]!;
                                balancePrefix = '+';
                                balanceWeight = FontWeight.bold;
                              } else if (solde < 0) {
                                balanceColor = Colors.green[700]!;
                                balanceWeight = FontWeight.bold;
                              }

                              final String initials = client.nomComplet.trim().isNotEmpty
                                  ? client.nomComplet.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                  : '?';

                              // Generate consistent background color based on name hash
                              final int colorHash = client.nomComplet.hashCode;
                              final List<Color> avatarColors = [
                                Colors.indigo[100]!,
                                Colors.teal[100]!,
                                Colors.blue[100]!,
                                Colors.purple[100]!,
                                Colors.orange[100]!,
                                Colors.pink[100]!,
                              ];
                              final List<Color> textColors = [
                                Colors.indigo[900]!,
                                Colors.teal[900]!,
                                Colors.blue[900]!,
                                Colors.purple[900]!,
                                Colors.orange[900]!,
                                Colors.pink[900]!,
                              ];
                              final int colorIndex = colorHash.abs() % avatarColors.length;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0.5,
                                child: ListTile(
                                  onTap: () => _navigateToClientDetail(client),
                                  leading: CircleAvatar(
                                    backgroundColor: avatarColors[colorIndex],
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        color: textColors[colorIndex],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    client.nomComplet,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    client.telephone,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$balancePrefix${currencyFormatter.format(solde.abs())}',
                                        style: TextStyle(
                                          color: balanceColor,
                                          fontWeight: balanceWeight,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        solde > 0
                                            ? 'doit'
                                            : (solde < 0 ? 'créditeur' : 'à jour'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: solde == 0 ? Colors.grey : balanceColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _filteredClients.length,
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddClient,
        tooltip: 'Ajouter un client',
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

// Helper delegate to use Builder with SliverChildBuilderDelegate
class SliverChildBuilderWithDetector extends SliverChildBuilderDelegate {
  SliverChildBuilderWithDetector(super.builder, {super.childCount});
}
