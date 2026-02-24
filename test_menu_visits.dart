import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(TestMenuVisitsApp());
}

class TestMenuVisitsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Menu Visits',
      home: TestMenuVisitsPage(),
    );
  }
}

class TestMenuVisitsPage extends StatefulWidget {
  @override
  _TestMenuVisitsPageState createState() => _TestMenuVisitsPageState();
}

class _TestMenuVisitsPageState extends State<TestMenuVisitsPage> {
  late IO.Socket socket;
  String _status = 'Conectando...';
  int _visitCount = 0;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    socket = IO.io('http://localhost:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      setState(() {
        _status = 'Conectado ao backend!';
      });
      print('✅ Socket conectado');
      
      // Enviar visita ao cardápio
      _sendMenuVisit();
    });

    socket.onDisconnect((_) {
      setState(() {
        _status = 'Desconectado';
      });
      print('❌ Socket desconectado');
    });

    socket.on('menu_visit_response', (data) {
      setState(() {
        _status = 'Resposta recebida: ${data['status']}';
        _visitCount++;
      });
      print('📱 Resposta menu_visit: $data');
    });

    socket.on('dashboard_data_updated', (data) {
      print('📊 Dashboard atualizado: ${data.keys}');
      if (data.containsKey('menu_visits')) {
        print('✅ Menu visits recebido no dashboard!');
      }
    });
  }

  void _sendMenuVisit() {
    final visitData = {
      'store_id': 1,
      'device_type': 'desktop',
      'source': 'direct',
      'session_id': 'test_session_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
    };

    socket.emit('menu_visit', visitData);
    print('📤 Enviando menu_visit: $visitData');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Menu Visits'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              'Visitas enviadas: $_visitCount',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _sendMenuVisit,
              child: Text('Enviar Menu Visit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                socket.emit('menu_analytics', {'store_id': 1});
              },
              child: Text('Solicitar Analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
