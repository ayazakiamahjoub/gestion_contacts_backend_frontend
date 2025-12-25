import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes/app_router.dart';
import 'services/api_service.dart';

// Variable globale pour stocker l'ID de l'utilisateur connecté
int? currentUserId;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service API (version simplifiée)
  await ApiService.init();
  
  print('🚀 Application démarrée en mode simplifié');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Gestion Contacts',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }
}