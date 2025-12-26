import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = []; // Pour la recherche
  bool _loading = false;
  bool _isSearching = false; // Mode recherche activé
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    
    try {
      final contactsData = await ApiService.getContacts();
      setState(() {
        _contacts = contactsData.map((json) => Contact.fromJson(json)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContact(int contactId, int index) async {
    try {
      await ApiService.deleteContact(contactId);
      setState(() {
        _contacts.removeAt(index);
        if (_isSearching) {
          _filteredContacts.removeWhere((c) => c.id == contactId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      context.go('/');
    }
  }

  // ===========================================
  // MÉTHODES DE RECHERCHE
  // ===========================================

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _filteredContacts = List.from(_contacts);
    });
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredContacts.clear();
    });
  }

  void _searchContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = List.from(_contacts);
      });
      return;
    }

    print('🔍 Recherche locale: "$query"');
    
    final filtered = _contacts.where((contact) {
      final fullName = '${contact.firstName} ${contact.lastName}'.toLowerCase();
      final phone = contact.phone.toLowerCase();
      final email = contact.email.toLowerCase();
      final searchQuery = query.toLowerCase();
      
      return fullName.contains(searchQuery) ||
             phone.contains(searchQuery) ||
             email.contains(searchQuery);
    }).toList();
    
    setState(() {
      _filteredContacts = filtered;
    });
    
    // Si pas de résultats en local et query assez longue, chercher sur le serveur
    if (filtered.isEmpty && query.length >= 2) {
      _searchOnServer(query);
    }
  }

  Future<void> _searchOnServer(String query) async {
    print('🌐 Recherche sur le serveur: "$query"');
    
    try {
      // Créer les headers avec le token
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Vérifier si on peut accéder au token via reflection ou autre méthode
      // Pour l'instant, on utilise une méthode alternative
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/contacts/search/$query'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final serverResults = data.map((json) => Contact.fromJson(json)).toList();
        
        // Ajouter les résultats du serveur (sans doublons)
        final existingIds = _contacts.map((c) => c.id).toSet();
        final newContacts = serverResults.where((c) => !existingIds.contains(c.id)).toList();
        
        if (newContacts.isNotEmpty) {
          setState(() {
            _contacts.addAll(newContacts);
            _filteredContacts = newContacts;
          });
          print('✅ ${newContacts.length} nouveaux contacts trouvés sur le serveur');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newContacts.length} nouveau(x) contact(s) trouvé(s)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ Token expiré pour la recherche');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expirée. Reconnectez-vous.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur recherche serveur: $e');
    }
  }

  // ===========================================
  // WIDGETS DE CONSTRUCTION
  // ===========================================

  Widget _buildContactCard(Contact contact, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(contact),
          child: Text(
            contact.firstName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '${contact.firstName} ${contact.lastName}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(contact.phone, style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (contact.email.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contact.email,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () async {
                await context.push('/edit-contact', extra: contact);
                _loadContacts();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                _showDeleteDialog(contact.id!, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(Contact contact) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    final index = (contact.id ?? contact.firstName.hashCode) % colors.length;
    return colors[index];
  }

  void _showDeleteDialog(int contactId, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce contact ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContact(contactId, index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContactsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.contacts, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Aucun contact',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await context.push('/add-contact');
              _loadContacts();
            },
            child: const Text('Ajouter un contact'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'Aucun contact trouvé pour "${_searchController.text}"',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _clearSearch,
            child: const Text('Voir tous les contacts'),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // BUILD PRINCIPAL
  // ===========================================

  @override
  Widget build(BuildContext context) {
    final displayContacts = _isSearching ? _filteredContacts : _contacts;
    final hasContacts = displayContacts.isNotEmpty;
    final isSearchingWithQuery = _isSearching && _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un contact...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onChanged: _searchContacts,
              )
            : const Text('Mes Contacts'),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
              tooltip: 'Rechercher',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadContacts,
              tooltip: 'Actualiser',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Déconnexion',
            ),
          ] else ...[
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _searchContacts('');
                },
                tooltip: 'Effacer',
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
              tooltip: 'Annuler la recherche',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Indicateur de recherche
                if (isSearchingWithQuery)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.grey.shade100,
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '${_filteredContacts.length} contact(s) trouvé(s)',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Liste des contacts
                Expanded(
                  child: !hasContacts && _isSearching
                      ? _buildNoSearchResults()
                      : !hasContacts
                          ? _buildNoContactsView()
                          : ListView.builder(
                              itemCount: displayContacts.length,
                              itemBuilder: (context, index) {
                                final contact = displayContacts[index];
                                final originalIndex = _contacts.indexOf(contact);
                                return _buildContactCard(contact, originalIndex);
                              },
                            ),
                ),
              ],
            ),
      floatingActionButton: !_isSearching
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/add-contact');
                _loadContacts();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}