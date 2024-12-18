import 'package:api_n7/pages/SuccessPage.dart';
import 'package:api_n7/pages/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyApp',
      home: HomePage(),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith("com.yourapp://callback")) {
          final uri = Uri.parse(settings.name!);
          final authCode = uri.queryParameters['code'];
          if (authCode != null) {
            print('Received auth code: $authCode');
            return MaterialPageRoute(
                builder: (context) => SuccessPage(authCode: authCode));
          }
        }
        return null;
      },
    );
  }
}