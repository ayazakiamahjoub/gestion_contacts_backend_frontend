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
  List<Contact> _filteredContacts = [];
  bool _loading = false;
  bool _isSearching = false;
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
        _contacts.sort((a, b) => a.firstName.compareTo(b.firstName));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        _showSnackBar('Erreur: $e', Colors.red);
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
        _showSnackBar('Contact supprimé', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: $e', Colors.red);
      }
    }
  }

  void _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      context.go('/');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ===========================================
  // MÉTHODES DE RECHERCHE
  // ===========================================

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _filteredContacts = List.from(_contacts);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isSearching) {
          FocusScope.of(context).requestFocus(FocusNode());
        }
      });
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
    
    if (filtered.isEmpty && query.length >= 2) {
      _searchOnServer(query);
    }
  }

  Future<void> _searchOnServer(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/contacts/search/$query'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final serverResults = data.map((json) => Contact.fromJson(json)).toList();
        
        final existingIds = _contacts.map((c) => c.id).toSet();
        final newContacts = serverResults.where((c) => !existingIds.contains(c.id)).toList();
        
        if (newContacts.isNotEmpty) {
          setState(() {
            _contacts.addAll(newContacts);
            _filteredContacts = newContacts;
          });
          
          if (mounted) {
            _showSnackBar('${newContacts.length} nouveau(x) contact(s) trouvé(s)', Colors.green);
          }
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          _showSnackBar('Session expirée. Reconnectez-vous.', Colors.red);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/edit-contact', extra: contact);
            _loadContacts();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _getAvatarColor(contact),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      contact.firstName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Contact Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${contact.firstName} ${contact.lastName}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            contact.phone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      if (contact.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.email_rounded,
                              size: 14,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                contact.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                      onPressed: () async {
                        await context.push('/edit-contact', extra: contact);
                        _loadContacts();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 22,
                        color: Colors.red.shade400,
                      ),
                      onPressed: () {
                        _showDeleteDialog(contact.id!, index);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(Contact contact) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.pink.shade600,
      Colors.deepOrange.shade600,
    ];
    final index = (contact.id ?? contact.firstName.hashCode) % colors.length;
    return colors[index];
  }

  void _showDeleteDialog(int contactId, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 32,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Supprimer le contact',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                'Êtes-vous sûr de vouloir supprimer ce contact ? Cette action est irréversible.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 28),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface.withOpacity(0.7),
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Annuler'),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteContact(contactId, index);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoContactsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.contacts_outlined,
                  size: 60,
                  color: colorScheme.primary,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            Text(
              'Aucun contact',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              'Commencez par ajouter votre premier contact',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Button
            ElevatedButton(
              onPressed: () async {
                await context.push('/add-contact');
                _loadContacts();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text('Ajouter un contact'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.search_off_rounded,
                  size: 60,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            Text(
              'Aucun résultat',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              'Aucun contact trouvé pour "${_searchController.text}"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Button
            OutlinedButton(
              onPressed: _clearSearch,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text('Voir tous les contacts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact...',
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchContacts('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                onChanged: _searchContacts,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _clearSearch,
            child: Text(
              'Annuler',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayContacts = _isSearching ? _filteredContacts : _contacts;
    final hasContacts = displayContacts.isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.05),
      body: Column(
        children: [
          // Custom App Bar
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Actions
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mes Contacts',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_contacts.length} contact${_contacts.length > 1 ? 's' : ''}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.search_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: _startSearch,
                              tooltip: 'Rechercher',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: colorScheme.primary,
                              ),
                              onPressed: _loadContacts,
                              tooltip: 'Actualiser',
                            ),
                            PopupMenuButton(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: colorScheme.primary,
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        color: colorScheme.onSurface,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text('Déconnexion'),
                                    ],
                                  ),
                                  onTap: _logout,
                                ),
                              ],
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

          // Search Bar (when searching)
          if (_isSearching) _buildSearchBar(),

          // Main Content
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement des contacts...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : !hasContacts && _isSearching
                    ? _buildNoSearchResults()
                    : !hasContacts
                        ? _buildNoContactsView()
                        : RefreshIndicator(
                            color: colorScheme.primary,
                            onRefresh: _loadContacts,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: displayContacts.length,
                              itemBuilder: (context, index) {
                                final contact = displayContacts[index];
                                final originalIndex = _contacts.indexOf(contact);
                                return _buildContactCard(contact, originalIndex);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: !_isSearching
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/add-contact');
                _loadContacts();
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}