import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/client.dart';

class AddClientScreen extends StatefulWidget {
  final int commerceId;

  const AddClientScreen({super.key, required this.commerceId});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    String tel = _telephoneController.text.trim();
    // Simple normalization: if it doesn't start with +, let's add +226 by default
    // or just let it be, but WhatsApp usually needs a country code.
    // Let's guide the user with a helper text and normalize it if they enter just 8 digits (common in Burkina Faso).
    if (!tel.startsWith('+')) {
      if (tel.length == 8) {
        tel = '+226$tel';
      } else {
        // Just generic validation, prepend + if needed or let the user write it.
        // Let's assume user followed instructions, or add + if missing and they typed 8/10 digits.
      }
    }

    final client = Client(
      commerceId: widget.commerceId,
      nomComplet: _nomController.text.trim(),
      telephone: tel,
      dateCreation: DateTime.now(),
    );

    try {
      await DatabaseHelper.instance.insertClient(client);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate we added a client
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création du client : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Client', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_outlined,
                      size: 60,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Ajouter un nouveau débiteur',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saisissez ses coordonnées réelles pour pouvoir envoyer des rappels automatiques via WhatsApp.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 36),

                // Name Field
                TextFormField(
                  controller: _nomController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet du Client *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer le nom du client';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Phone Field
                TextFormField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (WhatsApp) *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText: 'Ex : +22670000000 ou simplement 70000000',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer un numéro de téléphone';
                    }
                    // Validate digits count or format
                    final cleanValue = value.replaceAll(RegExp(r'\s+'), '');
                    if (cleanValue.length < 8) {
                      return 'Numéro trop court';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveClient,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: primaryColor,
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
                      : const Text(
                          'Enregistrer le Client',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
