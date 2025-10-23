import 'package:flutter/material.dart';

class HomeDarkBurguerPage extends StatelessWidget {
  const HomeDarkBurguerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Text('Dark Burguer', style: TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Text(
          'Layout do Burguer',
          style: TextStyle(color: Colors.amber, fontSize: 20),
        ),
      ),
    );
  }
}
