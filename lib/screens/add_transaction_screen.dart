import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/db_helper.dart';
import '../models/client.dart';
import '../models/commerce.dart';
import '../models/transaction.dart';

class AddTransactionScreen extends StatefulWidget {
  final int clientId;
  final TransactionType initialType;

  const AddTransactionScreen({
    super.key,
    required this.clientId,
    required this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  late TransactionType _typeTransaction;
  DateTime _dateTransaction = DateTime.now();
  DateTime? _dateEcheance;
  String? _photoPath;
  bool _isSaving = false;

  final dateFormatter = DateFormat('dd/MM/yyyy');
  final timeFormatter = DateFormat('HH:mm');

  List<TransactionModel> _unpaidDebts = [];
  int? _selectedDebtId;
  bool _loadingDebts = false;

  final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _typeTransaction = widget.initialType;
    _loadUnpaidDebts();
  }

  Future<void> _loadUnpaidDebts() async {
    setState(() {
      _loadingDebts = true;
    });
    try {
      final debts = await DatabaseHelper.instance.getUnpaidDebtsForClient(widget.clientId);
      setState(() {
        _unpaidDebts = debts;
        _loadingDebts = false;
      });
    } catch (e) {
      setState(() {
        _loadingDebts = false;
      });
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _photoPath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la capture de la photo : $e')),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateTransaction,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dateTransaction),
      );

      setState(() {
        if (pickedTime != null) {
          _dateTransaction = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _dateTransaction = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _dateTransaction.hour,
            _dateTransaction.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEcheanceDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateEcheance ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dateEcheance = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final double montant = double.parse(_montantController.text.trim());

    final tx = TransactionModel(
      clientId: widget.clientId,
      typeTransaction: _typeTransaction,
      montant: montant,
      dateTransaction: _dateTransaction,
      dateEcheance: _typeTransaction == TransactionType.dette ? _dateEcheance : null,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      photoPath: _photoPath,
      parentTransactionId: _typeTransaction == TransactionType.dette ? null : _selectedDebtId,
    );

    try {
      await DatabaseHelper.instance.insertTransaction(tx);
      
      // Auto-relance / Confirmation WhatsApp
      try {
        final Client? client = await DatabaseHelper.instance.getClient(widget.clientId);
        if (client != null) {
          final Commerce? commerce = await DatabaseHelper.instance.getCommerce(client.commerceId);
          if (commerce != null) {
            final cleanPhone = client.telephone.replaceAll(RegExp(r'\s+'), '');
            String phoneForWhatsApp = cleanPhone;
            if (phoneForWhatsApp.startsWith('+')) {
              phoneForWhatsApp = phoneForWhatsApp.substring(1);
            }
            final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(_dateTransaction);
            final String message;
            
            if (_typeTransaction == TransactionType.dette) {
              final String labelProd = _descriptionController.text.trim().isNotEmpty
                  ? "pour '${_descriptionController.text.trim()}'"
                  : "d'achats";
              message = "Bonjour ${client.nomComplet}, ceci est un reçu de confirmation de votre achat chez ${commerce.nomCommerce}. Vous avez pris un crédit d'une valeur de ${currencyFormatter.format(montant)} $labelProd le $dateStr. Merci.";
            } else {
              message = "Bonjour ${client.nomComplet}, ceci est un reçu de confirmation de votre règlement chez ${commerce.nomCommerce}. Nous avons bien reçu votre paiement de ${currencyFormatter.format(montant)} le $dateStr. Merci.";
            }

            final Uri url = Uri.parse('https://wa.me/$phoneForWhatsApp?text=${Uri.encodeComponent(message)}');
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        debugPrint('WhatsApp launch error: $e');
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate transaction was added
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDette = _typeTransaction == TransactionType.dette;
    final Color themeColor = isDette ? Colors.red[700]! : Colors.green[700]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDette ? 'Nouvelle Dette (Achat)' : 'Nouveau Paiement (Reçu)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector (DETTE vs PAIEMENT)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _typeTransaction = TransactionType.dette;
                              _selectedDebtId = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDette ? Colors.red[700] : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'DETTE (Achat)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDette ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _typeTransaction = TransactionType.paiement;
                            });
                            _loadUnpaidDebts();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isDette ? Colors.green[700] : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'PAIEMENT (Remboursement)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !isDette ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                if (!isDette) ...[
                  if (_loadingDebts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<int?>(
                      value: _selectedDebtId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Lier à une dette spécifique (Optionnel)',
                        prefixIcon: Icon(Icons.link, color: themeColor),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Paiement global (non lié à un produit)'),
                        ),
                        ..._unpaidDebts.map((dette) {
                          final desc = dette.description ?? 'Achat sans description';
                          final remaining = dette.remainingAmount ?? dette.montant;
                          return DropdownMenuItem<int?>(
                            value: dette.id,
                            child: Text(
                              '$desc (Reste : ${currencyFormatter.format(remaining)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedDebtId = val;
                          if (val != null) {
                            final targetDebt = _unpaidDebts.firstWhere((d) => d.id == val);
                            final remaining = targetDebt.remainingAmount ?? targetDebt.montant;
                            _montantController.text = remaining.toStringAsFixed(0);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ],

                // Amount text field
                TextFormField(
                  controller: _montantController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: 'FCFA',
                    suffixStyle: const TextStyle(fontSize: 18, color: Colors.grey),
                    labelText: 'Montant de l\'opération *',
                    labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: themeColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir un montant';
                    }
                    final double? val = double.tryParse(value.trim());
                    if (val == null || val <= 0) {
                      return 'Veuillez saisir un montant supérieur à 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Description field
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: isDette ? 'Détails de l\'achat (Optionnel)' : 'Détails du règlement (Optionnel)',
                    hintText: isDette ? 'Ex: 1 sac de riz, 2L d\'huile' : 'Ex: Acompte espèces, Orange Money',
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Date Picker button
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: themeColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date de l\'opération *',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Le ${dateFormatter.format(_dateTransaction)} à ${timeFormatter.format(_dateTransaction)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Date d'échéance selector for debts
                if (isDette) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date d\'échéance / Limite de paiement',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_dateEcheance != null)
                            TextButton(
                              onPressed: () => setState(() => _dateEcheance = null),
                              child: const Text('Effacer', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('+ 7j'),
                            selected: _dateEcheance != null &&
                                _dateEcheance!.difference(DateTime.now()).inDays >= 6 &&
                                _dateEcheance!.difference(DateTime.now()).inDays <= 8,
                            onSelected: (selected) {
                              setState(() {
                                _dateEcheance = selected ? DateTime.now().add(const Duration(days: 7)) : null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('+ 15j'),
                            selected: _dateEcheance != null &&
                                _dateEcheance!.difference(DateTime.now()).inDays >= 14 &&
                                _dateEcheance!.difference(DateTime.now()).inDays <= 16,
                            onSelected: (selected) {
                              setState(() {
                                _dateEcheance = selected ? DateTime.now().add(const Duration(days: 15)) : null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('+ 30j'),
                            selected: _dateEcheance != null &&
                                _dateEcheance!.difference(DateTime.now()).inDays >= 29 &&
                                _dateEcheance!.difference(DateTime.now()).inDays <= 31,
                            onSelected: (selected) {
                              setState(() {
                                _dateEcheance = selected ? DateTime.now().add(const Duration(days: 30)) : null;
                              });
                            },
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.event, color: _dateEcheance != null ? Colors.red[700] : Colors.grey),
                            tooltip: 'Choisir la date d\'échéance',
                            onPressed: _selectEcheanceDate,
                          ),
                        ],
                      ),
                      if (_dateEcheance != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Échéance : le ${dateFormatter.format(_dateEcheance!)}',
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Photo picker area
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[50],
                    ),
                    child: _photoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(File(_photoPath!), fit: BoxFit.cover),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    radius: 16,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _photoPath = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: themeColor),
                              const SizedBox(height: 8),
                              Text(
                                'Ajouter une photo (Optionnel)',
                                style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Preuve de paiement, reçu ou produit',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 36),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isDette ? 'Ajouter la Dette' : 'Enregistrer le Reçu',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
