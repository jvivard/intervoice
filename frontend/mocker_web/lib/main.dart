import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    runApp(const IntervoiceApp());
  } catch (e) {
    debugPrint('❌ Error initializing app: $e');
    // Fallback app without Firebase
    runApp(const IntervoiceApp());
  }
}

class IntervoiceApp extends StatelessWidget {
  const IntervoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Intervoice interview preparation',
        theme: AppTheme.lightTheme,
        home: const DashboardPage(),
        builder: (context, child) {
          // Set up error handling
          ErrorWidget.builder = (FlutterErrorDetails details) {
            debugPrint('❌ Widget error: ${details.exception}');
            return Material(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Something went wrong: ${details.exception}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Restart the app
                        runApp(const IntervoiceApp());
                      },
                      child: const Text('Restart App'),
                    ),
                  ],
                ),
              ),
            );
          };
          return child!;
        },
      ),
    );
  }
}
