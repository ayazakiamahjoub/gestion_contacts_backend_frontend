import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';// Pour web
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Pour émulateur Android
  
  static String? _token;

  // Méthode pour debug
  static void printDebugInfo() {
    print('🔍 DEBUG API Service:');
    print('   🌐 Base URL: $baseUrl');
    print('   🔑 Token présent: ${_token != null}');
    if (_token != null) {
      print('   🔑 Token: ${_token!.substring(0, 20)}...');
    }
  }

  static Future<void> init() async {
    print('✅ API Service initialisé');
  }

  static Future<void> setToken(String token) async {
    _token = token;
    print('🔑 Token enregistré: ${token.substring(0, 20)}...');
  }

  static Future<void> clearToken() async {
    _token = null;
    print('🔑 Token supprimé');
  }

  static Map<String, String> get _headers {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Test de connexion
  static Future<bool> checkConnection() async {
    print('🔍 Test de connexion backend...');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      print('✅ Backend accessible!');
      print('📊 Status: ${response.statusCode}');
      print('📄 Réponse: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Impossible de joindre le backend: $e');
      print('💡 Backend URL: $baseUrl');
      return false;
    }
  }

  // Authentication - CORRIGÉ
  static Future<Map<String, dynamic>> login(String email, String password) async {
    print('🔑 Tentative de connexion Flutter: $email');
    
    try {
      print('🌐 URL: $baseUrl/token');
      print('📧 Email: $email');
      print('🔐 Mot de passe: $password');
      
      // FORMAT EXACT comme Swagger
      final response = await http.post(
        Uri.parse('$baseUrl/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': email.trim(),      // ← 'username' pas 'email'
          'password': password,
          'grant_type': 'password',      // ← Obligatoire pour OAuth2
          'scope': '',                   // ← Vide mais présent
          'client_id': 'string',         // ← Comme Swagger
          'client_secret': '',           // ← Vide
        },
      );

      print('📊 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Connexion réussie via Flutter!');
        final data = jsonDecode(response.body);
        await setToken(data['access_token']);
        return data;
      } else {
        print('❌ Échec: ${response.statusCode}');
        print('❌ Détails: ${response.body}');
        throw Exception('Email ou mot de passe incorrect (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Exception lors du login: $e');
      print('💡 Vérifiez que le backend tourne sur $baseUrl');
      rethrow;
    }
  }

  // Register
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    print('📝 Tentative d\'inscription: $email');
    
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      print('✅ Inscription réussie');
      return jsonDecode(response.body);
    } else {
      print('❌ Échec inscription: ${response.statusCode}');
      print('❌ Réponse: ${response.body}');
      throw Exception('Erreur lors de l\'inscription');
    }
  }

  // Contacts
  static Future<List<dynamic>> getContacts() async {
    print('📋 Récupération des contacts');
    
    final response = await http.get(
      Uri.parse('$baseUrl/contacts'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      print('✅ Contacts récupérés');
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Non autorisé - Token invalide');
    } else {
      throw Exception('Erreur lors de la récupération des contacts');
    }
  }

  // CREATE CONTACT - UNE SEULE DÉFINITION
  static Future<Map<String, dynamic>> createContact({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
  }) async {
    print('=' * 50);
    print('🔄 DÉBUT createContact');
    print('   👤 Prénom: $firstName');
    print('   👤 Nom: $lastName');
    print('   📱 Téléphone: $phone');
    print('   📧 Email: ${email ?? "VIDE"}');
    
    // VÉRIFIER LE TOKEN
    if (_token == null) {
      print('❌ ERREUR: Aucun token JWT!');
      print('💡 Solution: Déconnectez-vous et reconnectez-vous');
      throw Exception('Non authentifié. Veuillez vous reconnecter.');
    }
    
    print('   🔑 Token présent: ${_token!.substring(0, 20)}...');
    
    try {
      // PRÉPARER LA REQUÊTE
      final url = '$baseUrl/contacts';
      final headers = _headers;
      final body = jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email ?? '',
      });
      
      print('   🌐 URL: $url');
      print('   📤 Headers: ${headers.containsKey('Authorization') ? "Avec Auth" : "Sans Auth"}');
      print('   📦 Body: $body');
      
      // ENVOYER LA REQUÊTE
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('   📊 Status Code: ${response.statusCode}');
      print('   📄 Réponse: ${response.body}');
      
      // ANALYSER LA RÉPONSE
      if (response.statusCode == 201) {
        print('✅ SUCCÈS: Contact créé');
        final result = jsonDecode(response.body);
        print('   📍 Contact ID: ${result['id']}');
        print('   👤 User ID: ${result['user_id']}');
        return result;
      } else if (response.statusCode == 401) {
        print('❌ ERREUR 401: Token invalide ou expiré');
        print('💡 Solution: Déconnectez-vous et reconnectez-vous');
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      } else if (response.statusCode == 422) {
        print('❌ ERREUR 422: Données invalides');
        print('💡 Vérifiez le format des données');
        throw Exception('Données invalides: ${response.body}');
      } else {
        print('❌ ERREUR ${response.statusCode}');
        throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ EXCEPTION dans createContact: $e');
      print('📋 Type d\'erreur: ${e.runtimeType}');
      
      if (e.toString().contains('Connection refused')) {
        print('💡 Le backend n\'est pas démarré!');
        throw Exception('Backend non accessible. Lancez python main.py');
      } else if (e.toString().contains('SocketException')) {
        print('💡 Problème de connexion réseau');
        throw Exception('Impossible de joindre le serveur');
      }
      
      rethrow;
    } finally {
      print('🔄 FIN createContact');
      print('=' * 50);
    }
  }

  static Future<Map<String, dynamic>> updateContact({
    required int contactId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
  }) async {
    print('✏️ Mise à jour du contact $contactId');
    
    final response = await http.put(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: _headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'email': email ?? '',
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Contact mis à jour');
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la mise à jour');
    }
  }

  static Future<void> deleteContact(int contactId) async {
    print('🗑️ Suppression du contact $contactId');
    
    final response = await http.delete(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      print('✅ Contact supprimé');
    } else {
      throw Exception('Erreur lors de la suppression');
    }
  }
}