import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/user.dart';

class ChangePasswordScreen extends StatefulWidget {
  final UserModel loggedUser;
  final Function(UserModel) onUserUpdated;

  const ChangePasswordScreen({
    super.key,
    required this.loggedUser,
    required this.onUserUpdated,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Verify current password
      if (_currentPinController.text != widget.loggedUser.motDePasse) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le code PIN actuel est incorrect.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Perform DB update
      final updatedUser = widget.loggedUser.copyWith(
        motDePasse: _newPinController.text,
      );

      await DatabaseHelper.instance.updateUser(updatedUser);
      
      widget.onUserUpdated(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Code PIN modifié avec succès !'),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la modification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le code PIN', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Changer votre code PIN d\'accès',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez votre code PIN actuel puis saisissez votre nouveau code d\'accès à 4 chiffres.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Current PIN field
              TextFormField(
                controller: _currentPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Code PIN Actuel',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir votre PIN actuel';
                  }
                  if (value.length < 4) {
                    return 'Le code PIN doit comporter 4 chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // New PIN field
              TextFormField(
                controller: _newPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nouveau Code PIN (4 chiffres)',
                  prefixIcon: Icon(Icons.lock_open_outlined),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir votre nouveau PIN';
                  }
                  if (value.length < 4) {
                    return 'Le code PIN doit comporter 4 chiffres';
                  }
                  if (value == _currentPinController.text) {
                    return 'Le nouveau PIN doit être différent de l\'actuel';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirm New PIN field
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Confirmer le Nouveau Code PIN',
                  prefixIcon: Icon(Icons.check_circle_outline),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez confirmer votre nouveau PIN';
                  }
                  if (value != _newPinController.text) {
                    return 'Les codes PIN ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('MODIFIER LE CODE PIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
