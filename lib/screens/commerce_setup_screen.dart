import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../models/commerce.dart';
import 'dashboard_screen.dart';

class CommerceSetupScreen extends StatefulWidget {
  final Commerce? existingCommerce;
  final Function(Commerce)? onSetupSuccess;

  const CommerceSetupScreen({super.key, this.existingCommerce, this.onSetupSuccess});

  @override
  State<CommerceSetupScreen> createState() => _CommerceSetupScreenState();
}

class _CommerceSetupScreenState extends State<CommerceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  String? _logoPath;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.existingCommerce?.nomCommerce ?? '');
    _telephoneController = TextEditingController(text: widget.existingCommerce?.telephoneCommerce ?? '');
    _adresseController = TextEditingController(text: widget.existingCommerce?.adresseCommerce ?? '');
    _logoPath = widget.existingCommerce?.logoPath;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _logoPath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image : $e')),
      );
    }
  }

  Future<void> _saveCommerce() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final commerce = Commerce(
      id: widget.existingCommerce?.id,
      nomCommerce: _nomController.text.trim(),
      telephoneCommerce: _telephoneController.text.trim(),
      adresseCommerce: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
      logoPath: _logoPath,
    );

    try {
      if (widget.existingCommerce == null) {
        // Insert new profile
        final id = await DatabaseHelper.instance.insertCommerce(commerce);
        final newCommerce = commerce.copyWith(id: id);
        if (mounted) {
          if (widget.onSetupSuccess != null) {
            widget.onSetupSuccess!(newCommerce);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(commerce: newCommerce),
              ),
            );
          }
        }
      } else {
        // Update existing profile
        await DatabaseHelper.instance.updateCommerce(commerce);
        if (mounted) {
          Navigator.pop(context, commerce);
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCommerce != null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                isEditing ? 'Modifier la Boutique' : 'Configurer DetteCash',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withBlue(200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 80,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isEditing) ...[
                      Text(
                        'Bienvenue dans DetteCash',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Commencez par configurer votre boutique pour personnaliser vos relances et reçus.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Image logo picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                              child: _logoPath == null
                                  ? Icon(Icons.add_a_photo_outlined, size: 36, color: primaryColor)
                                  : null,
                            ),
                            if (_logoPath != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  backgroundColor: primaryColor,
                                  radius: 18,
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Logo de la Boutique (Optionnel)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Store Name
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du Commerce *',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir le nom de la boutique';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Phone number
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone Mobile Money *',
                        prefixIcon: Icon(Icons.phone_android_outlined),
                        helperText: 'Ex: +22670000000 (Utilisé pour les paiements)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir le numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Address
                    TextFormField(
                      controller: _adresseController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Adresse du Commerce (Optionnel)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Submit button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveCommerce,
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
                          : Text(
                              isEditing ? 'Enregistrer les modifications' : 'Créer ma Boutique',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
