import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../models/contact.dart';

class EditContactPage extends StatefulWidget {
  final Contact contact;
  
  const EditContactPage({Key? key, required this.contact}) : super(key: key);

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _loading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('📱 EditContactPage initialisé pour contact ID: ${widget.contact.id}');
    
    _firstNameController = TextEditingController(text: widget.contact.firstName);
    _lastNameController = TextEditingController(text: widget.contact.lastName);
    _phoneController = TextEditingController(text: widget.contact.phone);
    _emailController = TextEditingController(text: widget.contact.email);
  }

  Future<void> _updateContact() async {
    print('=' * 50);
    print('🔄 TENTATIVE MODIFICATION CONTACT - DÉBUT');
    print('📝 Contact ID: ${widget.contact.id}');
    
    // VÉRIFICATION DES CHAMPS
    if (_firstNameController.text.isEmpty) {
      _showError('Le prénom est obligatoire');
      return;
    }
    if (_lastNameController.text.isEmpty) {
      _showError('Le nom est obligatoire');
      return;
    }
    if (_phoneController.text.isEmpty) {
      _showError('Le téléphone est obligatoire');
      return;
    }

    print('📝 Données modifiées:');
    print('   👤 Prénom: ${_firstNameController.text} (avant: ${widget.contact.firstName})');
    print('   👤 Nom: ${_lastNameController.text} (avant: ${widget.contact.lastName})');
    print('   📱 Téléphone: ${_phoneController.text} (avant: ${widget.contact.phone})');
    print('   📧 Email: ${_emailController.text} (avant: ${widget.contact.email})');
    
    setState(() => _loading = true);

    try {
      print('📤 Appel de ApiService.updateContact...');
      
      // Vérifier que le contact a un ID
      if (widget.contact.id == null) {
        throw Exception('Contact ID manquant');
      }
      
      await ApiService.updateContact(
        contactId: widget.contact.id!,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      );

      print('✅ Contact modifié avec succès côté API!');
      
      if (mounted) {
        _showSuccess('✅ Contact modifié avec succès');
        
        // Attendre un peu pour que l'utilisateur voie le message
        await Future.delayed(const Duration(milliseconds: 500));
        
        print('🔄 Retour à la page précédente...');
        context.pop(); // Retour à la page d'accueil
      }
    } catch (e) {
      print('❌ ERREUR lors de la modification: $e');
      
      if (mounted) {
        String message = 'Erreur lors de la modification du contact';
        
        if (e.toString().contains('401') || e.toString().contains('Non authentifié')) {
          message = 'Session expirée. Veuillez vous reconnecter.';
        } else if (e.toString().contains('404')) {
          message = 'Contact non trouvé';
        } else if (e.toString().contains('422')) {
          message = 'Données invalides. Vérifiez les informations.';
        }
        
        _showError(message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      print('🔄 TENTATIVE MODIFICATION CONTACT - FIN');
      print('=' * 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le contact'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!_loading) {
              context.pop();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Prénom *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 30),
            
            // Informations du contact
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations du contact:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text('ID: ${widget.contact.id}'),
                  Text('Créé le: ${widget.contact.createdAt.toString().split(' ')[0]}'),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            // Bouton de modification
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _updateContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Enregistrer les modifications',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
            
            // Bouton annuler
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: TextButton(
                onPressed: _loading ? null : () => context.pop(),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('🗑️ EditContactPage désactivé');
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}