import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/user.dart';

class UserManagementScreen extends StatefulWidget {
  final UserModel currentUser;

  const UserManagementScreen({super.key, required this.currentUser});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await DatabaseHelper.instance.getAllUsers();
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    if (user.id == widget.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas supprimer votre propre compte.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Êtes-vous sûr de vouloir supprimer définitivement ${user.nom} ? Cet utilisateur ne pourra plus se connecter.'),
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
        await DatabaseHelper.instance.deleteUser(user.id!);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur supprimé avec succès.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final pinController = TextEditingController();
    String selectedRole = 'USER';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Créer un Utilisateur'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir un nom';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de téléphone',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir un numéro';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Initial PIN
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Code PIN Initial (4 chiffres)',
                          prefixIcon: Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir un code PIN';
                          }
                          if (value.length < 4) {
                            return 'Le code PIN doit faire 4 chiffres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Role Selector
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rôle',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USER', child: Text('Employé / Utilisateur')),
                          DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() {
                              selectedRole = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ANNULER'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Check for duplicate phone
                      final cleanPhone = phoneController.text.trim();
                      final isDuplicate = _users.any((u) => u.telephone == cleanPhone);
                      if (isDuplicate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ce numéro de téléphone est déjà attribué.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final newUser = UserModel(
                        nom: nameController.text.trim(),
                        telephone: cleanPhone,
                        motDePasse: pinController.text,
                        role: selectedRole,
                      );

                      try {
                        await DatabaseHelper.instance.insertUser(newUser);
                        Navigator.pop(context);
                        _loadUsers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Utilisateur créé avec succès !'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur lors de la création : $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('CRÉER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: primaryColor.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'En tant qu\'administrateur, vous pouvez ajouter ou supprimer des comptes d\'utilisateurs pour cette boutique.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('Aucun utilisateur trouvé.'))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isMe = user.id == widget.currentUser.id;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: user.role == 'ADMIN'
                                      ? Colors.amber[100]
                                      : Colors.indigo[100],
                                  child: Icon(
                                    user.role == 'ADMIN'
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    color: user.role == 'ADMIN'
                                        ? Colors.amber[800]
                                        : primaryColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      user.nom,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Moi', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  'Tél: ${user.telephone} | Rôle: ${user.role == 'ADMIN' ? 'Admin' : 'Employé'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: isMe
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteUser(user),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        tooltip: 'Ajouter un utilisateur',
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }
}
