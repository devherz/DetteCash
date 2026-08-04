import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/commerce.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import '../database/db_helper.dart';
import '../services/backend_service.dart';
import 'commerce_setup_screen.dart';
import 'change_password_screen.dart';
import 'user_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Commerce commerce;
  final UserModel? loggedUser;
  final Function(UserModel)? onUserUpdated;

  const SettingsScreen({
    super.key,
    required this.commerce,
    this.loggedUser,
    this.onUserUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Commerce _commerce;
  bool _hasChanges = false;

  List<File> _backups = [];
  bool _loadingBackups = false;
  bool _creatingBackup = false;

  final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _commerce = widget.commerce;
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _loadingBackups = true;
    });
    try {
      final list = await DatabaseHelper.instance.listBackups();
      setState(() {
        _backups = list;
        _loadingBackups = false;
      });
    } catch (_) {
      setState(() {
        _loadingBackups = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommerceSetupScreen(existingCommerce: _commerce),
      ),
    );

    if (result is Commerce) {
      setState(() {
        _commerce = result;
        _hasChanges = true;
      });
    }
  }

  Future<void> _createNewBackup() async {
    setState(() {
      _creatingBackup = true;
    });

    try {
      final backupFile = await DatabaseHelper.instance.createBackup();
      setState(() {
        _creatingBackup = false;
      });
      _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sauvegarde créée avec succès : ${backupFile.path.split(Platform.pathSeparator).last}'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _creatingBackup = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de création de sauvegarde : $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _confirmRestoreBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: const Text('Attention ! Vos données actuelles seront remplacées par celles de cette sauvegarde. Cette opération va écraser la base de données actuelle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTAURER'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.restoreBackup(file);
        _hasChanges = true;
        
        // Refresh commerce profile
        final refreshed = await DatabaseHelper.instance.getCommerce(_commerce.id!);
        if (refreshed != null) {
          setState(() {
            _commerce = refreshed;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Restauration effectuée avec succès !'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de restauration : $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  Future<void> _shareBackup(File file) async {
    try {
      await DatabaseHelper.instance.shareBackup(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }

  Future<void> _importExternalBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!filePath.endsWith('.db')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez sélectionner un fichier de sauvegarde SQLite valide (.db)')),
            );
          }
          return;
        }

        final selectedFile = File(filePath);
        await _confirmRestoreBackup(selectedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'importation : $e')),
        );
      }
    }
  }

  Future<void> _editWhatsappTemplate() async {
    final controller = TextEditingController(
      text: _commerce.customWhatsappTemplate ?? Commerce.defaultWhatsappTemplate,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modèle de relance WhatsApp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balises disponibles :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Text(
                '{nom_client} • {solde_du} • {nom_commerce} • {telephone_commerce}',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Saisissez le modèle...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = Commerce.defaultWhatsappTemplate;
            },
            child: const Text('RÉINITIALISER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedCommerce = _commerce.copyWith(customWhatsappTemplate: result);
      await DatabaseHelper.instance.updateCommerce(updatedCommerce);
      setState(() {
        _commerce = updatedCommerce;
        _hasChanges = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modèle WhatsApp mis à jour avec succès !')),
        );
      }
    }
  }

  Future<void> _optimizeDatabase() async {
    try {
      await BackendService.instance.optimizeDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base de données défragmentée et optimisée avec succès (VACUUM OK) !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'optimisation : $e')),
        );
      }
    }
  }

  Future<void> _exportJsonData() async {
    try {
      final jsonStr = await BackendService.instance.exportFullJson();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}${Platform.pathSeparator}dettecash_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Exportation complète des données DetteCash (JSON)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'exportation JSON : $e')),
        );
      }
    }
  }

  Future<void> _showAuditLogsModal() async {
    final logs = await BackendService.instance.getAuditHistory(limit: 50);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Journal d\'Activité (Audit)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: logs.isEmpty
                        ? const Center(child: Text('Aucune activité enregistrée.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final item = logs[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  item.action.contains('DETTE')
                                      ? Icons.arrow_upward
                                      : (item.action.contains('REGLEMENT') ? Icons.arrow_downward : Icons.history),
                                  color: item.action.contains('DETTE') ? Colors.red : Colors.green,
                                ),
                                title: Text(item.action, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${item.details}\n${DateFormat('dd/MM/yyyy à HH:mm:ss').format(item.timestamp)}'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la sauvegarde ?'),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement ce fichier de sauvegarde ?'),
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
        await DatabaseHelper.instance.deleteBackup(file);
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sauvegarde supprimée')),
          );
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

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Profil'),
              Tab(icon: Icon(Icons.contact_support_outlined), text: 'Contact'),
              Tab(icon: Icon(Icons.info_outline), text: 'À propos'),
            ],
          ),
        ),
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              Navigator.pop(context, _hasChanges);
            }
          },
          child: TabBarView(
            children: [
              // 1. PROFILE TAB
              _buildProfileTab(primaryColor, theme),

              // 2. CONTACT TAB
              _buildContactTab(primaryColor, theme),

              // 3. ABOUT TAB
              _buildAboutTab(primaryColor, theme),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'version 1.0.0 by Grimm',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(Color primaryColor, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Store Logo
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _commerce.logoPath != null ? FileImage(File(_commerce.logoPath!)) : null,
                    child: _commerce.logoPath == null
                        ? Icon(Icons.storefront_outlined, size: 40, color: primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _commerce.nomCommerce,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Mobile Money : ${_commerce.telephoneCommerce}',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_commerce.adresseCommerce != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _commerce.adresseCommerce!,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('MODIFIER LE PROFIL BOUTIQUE', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (widget.loggedUser != null) ...[
            const SizedBox(height: 24),
            Text(
              'Sécurité & Utilisateurs',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0.5,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_open_outlined, color: primaryColor),
                    title: const Text('Changer de code PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Modifier votre code PIN à 4 chiffres'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (widget.onUserUpdated != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangePasswordScreen(
                              loggedUser: widget.loggedUser!,
                              onUserUpdated: widget.onUserUpdated!,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (widget.loggedUser!.role == 'ADMIN') ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.people_outline, color: primaryColor),
                      title: const Text('Gérer les utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Créer et supprimer des comptes employés'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserManagementScreen(
                              currentUser: widget.loggedUser!,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: Text('Session active : ${widget.loggedUser!.nom}'),
                    onTap: () {
                      Navigator.pop(context, 'LOGOUT');
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.message_outlined, color: Colors.green),
                  title: const Text('Modèle de relance WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Personnaliser le texte automatique'),
                  trailing: const Icon(Icons.edit_note),
                  onTap: _editWhatsappTemplate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined, color: Colors.indigo),
                  title: const Text('Journal d\'Activité & Traçabilité', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Consulter les logs d\'audit de la base'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAuditLogsModal,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: Colors.orange),
                  title: const Text('Optimiser la base (VACUUM)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Défragmenter et réduire la taille disque'),
                  onTap: _optimizeDatabase,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_outlined, color: Colors.purple),
                  title: const Text('Exporter toutes les données (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Générer un fichier texte universel'),
                  onTap: _exportJsonData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sauvegardes Locales',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined),
                    color: Colors.teal,
                    tooltip: 'Importer une sauvegarde (.db)',
                    onPressed: _importExternalBackup,
                  ),
                  if (_creatingBackup)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: primaryColor,
                      tooltip: 'Créer une sauvegarde',
                      onPressed: _createNewBackup,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingBackups)
            const Center(child: CircularProgressIndicator())
          else if (_backups.isEmpty)
            Card(
              color: Colors.grey[50],
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Aucune sauvegarde disponible. Appuyez sur le bouton + pour en créer une.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backups.length,
              itemBuilder: (context, index) {
                final file = _backups[index];
                final String fileName = file.path.split(Platform.pathSeparator).last;
                
                // Parse date from file name (backup_yyyyMMdd_HHmmss.db)
                String dateStr = fileName;
                try {
                  final parts = fileName.split('_');
                  if (parts.length >= 3) {
                    final datePart = parts[1]; // yyyyMMdd
                    final timePart = parts[2].split('.').first; // HHmmss
                    final year = int.parse(datePart.substring(0, 4));
                    final month = int.parse(datePart.substring(4, 6));
                    final day = int.parse(datePart.substring(6, 8));
                    final hour = int.parse(timePart.substring(0, 2));
                    final minute = int.parse(timePart.substring(2, 4));
                    final sec = int.parse(timePart.substring(4, 6));
                    final dt = DateTime(year, month, day, hour, minute, sec);
                    dateStr = DateFormat('dd/MM/yyyy à HH:mm:ss').format(dt);
                  }
                } catch (_) {}

                String sizeStr = '0 KB';
                try {
                  final len = file.lengthSync();
                  sizeStr = '${(len / 1024).toStringAsFixed(1)} KB';
                } catch (_) {}

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.backup_table, color: Colors.blue),
                    title: Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Taille : $sizeStr',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: Colors.blue),
                          tooltip: 'Partager / Exporter',
                          onPressed: () => _shareBackup(file),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_backup_restore, color: Colors.teal),
                          tooltip: 'Restaurer',
                          onPressed: () => _confirmRestoreBackup(file),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDeleteBackup(file),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContactTab(Color primaryColor, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.contact_support_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Besoin d\'assistance ?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Notre équipe d\'assistance Grimm est disponible pour répondre à vos questions ou recueillir vos commentaires.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // WhatsApp Support Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('Support WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Discuter en ligne avec un agent'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _launchUrl('https://wa.me/22670000000?text=Bonjour%20support%20DetteCash'),
            ),
          ),
          const SizedBox(height: 10),

          // Email Support Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.blue),
              title: const Text('Support Email', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Nous écrire par courrier électronique'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _launchUrl('mailto:support@dettecash.com?subject=Assistance%20DetteCash'),
            ),
          ),
          const SizedBox(height: 10),

          // Phone Call Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined, color: Colors.orange),
              title: const Text('Service Client', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Appeler directement Grimm'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _launchUrl('tel:+22670000000'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab(Color primaryColor, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Logo styled box
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.wallet_outlined,
                size: 64,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'DetteCash',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          Text(
            'Version 1.0.0',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'DetteCash est une solution locale, fonctionnant 100% hors-ligne et hautement sécurisée pour les smartphones Android. Elle permet aux commerçants de gérer simplement leurs comptes clients, d\'enregistrer leurs achats à crédit (dettes) et leurs remboursements (paiements), et d\'envoyer des relances pré-remplies directement via WhatsApp.',
                style: TextStyle(fontSize: 14, height: 1.5),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.offline_bolt_outlined, color: Colors.blue),
                  title: Text('100% Hors-ligne'),
                  subtitle: Text('Aucune connexion requise, vos données restent privées.'),
                ),
                ListTile(
                  leading: Icon(Icons.security, color: Colors.teal),
                  title: Text('Sécurisé et local'),
                  subtitle: Text('Stockage crypté en base locale de votre smartphone.'),
                ),
                ListTile(
                  leading: Icon(Icons.flash_on_outlined, color: Colors.amber),
                  title: Text('Relance rapide'),
                  subtitle: Text('Modèle de message intelligent envoyé sur WhatsApp.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
