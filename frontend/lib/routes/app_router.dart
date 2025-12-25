import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/home_page.dart';
import '../pages/add_contact_page.dart';
import '../pages/edit_contact_page.dart';
import '../models/contact.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'login',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            child: const LoginPage(),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            child: const RegisterPage(),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            child: const HomePage(),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/add-contact',
        name: 'add-contact',
        pageBuilder: (context, state) {
          return MaterialPage<void>(
            child: const AddContactPage(),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/edit-contact',
        name: 'edit-contact',
        pageBuilder: (context, state) {
          if (state.extra != null && state.extra is Contact) {
            final contact = state.extra as Contact;
            return MaterialPage<void>(
              child: EditContactPage(contact: contact),
              key: state.pageKey,
            );
          } else {
            return MaterialPage<void>(
              child: const HomePage(),
              key: state.pageKey,
            );
          }
        },
      ),
    ],
  );
}