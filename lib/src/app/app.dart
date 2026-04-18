import 'package:flutter/material.dart';

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relay',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.lightBlue)),
      home: const Placeholder(),
    );
  }
}
