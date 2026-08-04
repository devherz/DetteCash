import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../database/db_helper.dart';
import '../models/commerce.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../utils/pdf_helper.dart';
import 'add_transaction_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  final Commerce commerce;

  const ClientDetailScreen({super.key, required this.client, required this.commerce});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Client _client;
  late Commerce _commerce;
  List<TransactionModel> _transactions = [];
  double _totalDette = 0.0;
  double _totalPaiement = 0.0;
  bool _isLoading = true;
  bool _hasChanges = false;

  final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
  final dateFormatter = DateFormat('dd/MM/yyyy à HH:mm');

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _commerce = widget.commerce;
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedClient = await DatabaseHelper.instance.getClient(_client.id!);
      if (updatedClient != null) {
        _client = updatedClient;
      }

      final txs = await DatabaseHelper.instance.getTransactionsForClient(_client.id!);
      
      double d = 0;
      double p = 0;
      for (var tx in txs) {
        if (tx.typeTransaction == TransactionType.dette) {
          d += tx.montant;
        } else {
          p += tx.montant;
        }
      }

      setState(() {
        _transactions = txs;
        _totalDette = d;
        _totalPaiement = p;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement de l\'historique : $e')),
        );
      }
    }
  }

  double get _solde => _totalDette - _totalPaiement;

  Future<void> _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le Client'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${_client.nomComplet} ainsi que tout son historique de transactions ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteClient(_client.id!);
        if (mounted) {
          Navigator.pop(context, true); // Pop back to dashboard and notify to refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de suppression : $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la Transaction'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette transaction ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteTransaction(transaction.id!);
        _hasChanges = true;
        _loadClientData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression de la transaction : $e')),
          );
        }
      }
    }
  }

  Future<void> _launchCall() async {
    final cleanPhone = _client.telephone.replaceAll(RegExp(r'\s+'), '');
    final Uri url = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer l\'appel téléphonique : $e')),
        );
      }
    }
  }

  Future<void> _launchWhatsAppRelance() async {
    final cleanPhone = _client.telephone.replaceAll(RegExp(r'\s+'), '');
    // WhatsApp format: phone should not contain '+' or spaces, but the wa.me link can handle prefixing without '+'
    String phoneForWhatsApp = cleanPhone;
    if (phoneForWhatsApp.startsWith('+')) {
      phoneForWhatsApp = phoneForWhatsApp.substring(1);
    }

    final String message = _commerce.buildWhatsappReminder(
      clientName: _client.nomComplet,
      soldeDuFormatted: currencyFormatter.format(_solde),
    );
    
    final Uri url = Uri.parse('https://wa.me/$phoneForWhatsApp?text=${Uri.encodeComponent(message)}');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback: try opening as standard default browser URL
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp. Vérifiez que l\'application est installée.')),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddTransaction(TransactionType type) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          clientId: _client.id!,
          initialType: type,
        ),
      ),
    );

    if (result == true) {
      _hasChanges = true;
      _loadClientData();
    }
  }

  Future<void> _exportAccountStatement() async {
    try {
      final pdfData = await PdfHelper.generateAccountStatementPdf(_commerce, _client, _transactions);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'Releve_compte_${_client.nomComplet.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
        );
      }
    }
  }

  Future<void> _exportTransactionReceipt(TransactionModel transaction) async {
    try {
      TransactionModel? parentDette;
      if (transaction.parentTransactionId != null) {
        try {
          parentDette = _transactions.firstWhere((t) => t.id == transaction.parentTransactionId);
        } catch (_) {
          try {
            final clientTxs = await DatabaseHelper.instance.getTransactionsForClient(transaction.clientId);
            parentDette = clientTxs.firstWhere((t) => t.id == transaction.parentTransactionId);
          } catch (_) {}
        }
      }

      final pdfData = await PdfHelper.generateTransactionReceiptPdf(
        _commerce,
        _client,
        transaction,
        parentDette,
      );

      final String docName = transaction.typeTransaction == TransactionType.dette
          ? 'Facture_${transaction.id}_${_client.nomComplet.replaceAll(' ', '_')}.pdf'
          : 'Recu_${transaction.id}_${_client.nomComplet.replaceAll(' ', '_')}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: docName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
        );
      }
    }
  }

  void _showPhotoDialog(String photoPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(File(photoPath), fit: BoxFit.contain),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionModel> get _dettesNonDebutees {
    return _transactions.where((tx) {
      if (tx.typeTransaction != TransactionType.dette) return false;
      final rem = tx.remainingAmount ?? tx.montant;
      return rem == tx.montant;
    }).toList();
  }

  List<TransactionModel> get _dettesEnCours {
    return _transactions.where((tx) {
      if (tx.typeTransaction != TransactionType.dette) return false;
      final rem = tx.remainingAmount ?? tx.montant;
      return rem > 0 && rem < tx.montant;
    }).toList();
  }

  List<TransactionModel> get _dettesSoldees {
    return _transactions.where((tx) {
      if (tx.typeTransaction != TransactionType.dette) return false;
      final rem = tx.remainingAmount ?? tx.montant;
      return rem <= 0;
    }).toList();
  }

  List<TransactionModel> get _unlinkedPayments {
    return _transactions.where((tx) => tx.typeTransaction == TransactionType.paiement && tx.parentTransactionId == null).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Color balanceColor = Colors.grey[700]!;
    if (_solde > 0) {
      balanceColor = Colors.red[700]!;
    } else if (_solde < 0) {
      balanceColor = Colors.green[700]!;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Client', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exporter le Relevé PDF',
            onPressed: _exportAccountStatement,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Supprimer ce Client',
            onPressed: _deleteClient,
          ),
        ],
        elevation: 0,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.pop(context, _hasChanges);
          }
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Client Card Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                _client.nomComplet.trim().isNotEmpty ? _client.nomComplet[0].toUpperCase() : '?',
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _client.nomComplet,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _client.telephone,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ajouté le : ${DateFormat('dd/MM/yyyy').format(_client.dateCreation)}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Contact Actions Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _launchCall,
                                icon: const Icon(Icons.call, size: 18),
                                label: const Text('Appeler'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _launchWhatsAppRelance,
                                icon: const Icon(Icons.message, size: 18),
                                label: const Text('Relancer (WhatsApp)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Solde Banner
                  Container(
                    width: double.infinity,
                    color: balanceColor.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _solde > 0 ? 'Solde dû par le client :' : (_solde < 0 ? 'Solde créditeur :' : 'Compte équilibré'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _solde == 0 ? Colors.grey[600] : balanceColor,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(_solde.abs()),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _solde == 0 ? Colors.grey[800] : balanceColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  TabBar(
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(
                        child: Text(
                          'Non débuté\n(${_dettesNonDebutees.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Tab(
                        child: Text(
                          'En cours\n(${_dettesEnCours.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Tab(
                        child: Text(
                          'Soldé\n(${_dettesSoldees.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Transaction List
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetteList(_dettesNonDebutees, theme, primaryColor),
                        _buildDetteList(_dettesEnCours, theme, primaryColor, showUnlinkedPayments: true),
                        _buildDetteList(_dettesSoldees, theme, primaryColor),
                      ],
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
                    decoration: BoxDecoration(
                      color: theme.canvasColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _navigateToAddTransaction(TransactionType.paiement),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('ENREGISTRER PAIEMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _navigateToAddTransaction(TransactionType.dette),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('AJOUTER DETTE', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

  Widget _buildDetteList(List<TransactionModel> dettes, ThemeData theme, Color primaryColor, {bool showUnlinkedPayments = false}) {
    final showPaymentsList = showUnlinkedPayments && _unlinkedPayments.isNotEmpty;
    
    if (dettes.isEmpty && !showPaymentsList) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Aucune dette dans cette catégorie',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: dettes.length + (showPaymentsList ? _unlinkedPayments.length + 1 : 0),
      itemBuilder: (context, index) {
        if (index < dettes.length) {
          final tx = dettes[index];
          final linkedPayments = _transactions.where((t) => t.typeTransaction == TransactionType.paiement && t.parentTransactionId == tx.id).toList();

          final double rem = tx.remainingAmount ?? tx.montant;
          final bool isFullyPaid = rem <= 0;
          final bool isPartiallyPaid = rem > 0 && rem < tx.montant;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward,
                          color: Colors.red[700],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.description ?? 'Achat à crédit',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Montant initial : ${currencyFormatter.format(tx.montant)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            if (tx.dateEcheance != null && !isFullyPaid) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    tx.isOverdue ? Icons.error_outline : Icons.event_outlined,
                                    size: 13,
                                    color: tx.isOverdue ? Colors.red[700] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tx.isOverdue
                                        ? 'EN RETARD DE ${tx.overdueDays} J (Échéance: ${DateFormat('dd/MM/yyyy').format(tx.dateEcheance!)})'
                                        : 'Échéance le ${DateFormat('dd/MM/yyyy').format(tx.dateEcheance!)}',
                                    style: TextStyle(
                                      color: tx.isOverdue ? Colors.red[700] : Colors.grey[600],
                                      fontWeight: tx.isOverdue ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isFullyPaid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SOLDÉ',
                                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            )
                          else ...[
                            Text(
                              currencyFormatter.format(rem),
                              style: TextStyle(
                                color: isPartiallyPaid ? Colors.orange[800] : Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Reste à payer',
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateFormatter.format(tx.dateTransaction),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      Row(
                        children: [
                          if (tx.photoPath != null) ...[
                            GestureDetector(
                              onTap: () => _showPhotoDialog(tx.photoPath!),
                              child: Row(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 13, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Photo',
                                    style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          GestureDetector(
                            onTap: () => _exportTransactionReceipt(tx),
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf, size: 13, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'PDF',
                                  style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _deleteTransaction(tx),
                            child: Icon(Icons.delete_outline, size: 16, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (linkedPayments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Règlements reçus :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    ...linkedPayments.map((payment) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 12, color: Colors.green[600]),
                                const SizedBox(width: 6),
                                Text(
                                  '${DateFormat('dd/MM/yy').format(payment.dateTransaction)} - Règlement',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '-${currencyFormatter.format(payment.montant)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700]),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _exportTransactionReceipt(payment),
                                  child: Icon(Icons.picture_as_pdf, size: 12, color: primaryColor),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _deleteTransaction(payment),
                                  child: Icon(Icons.close, size: 12, color: Colors.red[300]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          );
        } else {
          final int paymentIndex = index - dettes.length;
          if (paymentIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 8.0),
              child: Text(
                'Règlements Généraux (Non affectés)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            );
          }
          final payment = _unlinkedPayments[paymentIndex - 1];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.green[50]?.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(Icons.arrow_downward, color: Colors.green[700]),
              title: Text(
                payment.description ?? 'Règlement général',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                dateFormatter.format(payment.dateTransaction),
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '-${currencyFormatter.format(payment.montant)}',
                    style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf, size: 18, color: primaryColor),
                    tooltip: 'Télécharger le PDF',
                    onPressed: () => _exportTransactionReceipt(payment),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteTransaction(payment),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
