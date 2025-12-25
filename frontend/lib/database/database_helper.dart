import '../services/api_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // Test de connexion simple
  Future<bool> checkConnection() async {
    return await ApiService.checkConnection();
  }

  // Méthode simplifiée de connexion
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final response = await ApiService.login(email, password);
      // Le token est déjà enregistré dans ApiService.login()
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Inscription
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    await ApiService.clearToken();
  }

  // Récupérer tous les contacts
  Future<List<dynamic>> getContacts() async {
    try {
      return await ApiService.getContacts();
    } catch (e) {
      rethrow;
    }
  }

  // Créer un contact
  Future<Map<String, dynamic>> createContact({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
  }) async {
    try {
      return await ApiService.createContact(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Mettre à jour un contact
  Future<Map<String, dynamic>> updateContact({
    required int contactId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
  }) async {
    try {
      return await ApiService.updateContact(
        contactId: contactId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Supprimer un contact
  Future<void> deleteContact(int contactId) async {
    try {
      await ApiService.deleteContact(contactId);
    } catch (e) {
      rethrow;
    }
  }
}