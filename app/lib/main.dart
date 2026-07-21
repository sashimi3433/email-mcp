import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmailMcpApp());
}

class EmailMcpApp extends StatelessWidget {
  const EmailMcpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email MCP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(api: ApiService()),
    );
  }
}
