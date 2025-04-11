// main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Asistencia QR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usuarioController = TextEditingController();
  final contrasenaController = TextEditingController();
  bool isLoading = false;
  String? error;

  Future<void> validarLogin() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final url = Uri.parse(
        'https://api.sheety.co/b886748cc8aaf049fce079718ae15445/registrosQr/usuarios');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final usuarios = data['usuarios'] as List;

      final encontrado = usuarios.firstWhere(
        (u) =>
            u['usuario'] == usuarioController.text.trim() &&
            u['contraseña'] == contrasenaController.text.trim(),
        orElse: () => null,
      );

      if (encontrado != null) {
        final int numero = encontrado['no'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(noUsuario: numero),
          ),
        );
      } else {
        setState(() {
          error = 'Usuario o contraseña incorrectos';
        });
      }
    } else {
      setState(() {
        error = 'Error al conectar con Sheety';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inicio de Sesión')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: usuarioController,
              decoration: InputDecoration(labelText: 'Usuario'),
            ),
            TextField(
              controller: contrasenaController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : validarLogin,
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Ingresar'),
            ),
            if (error != null) ...[
              const SizedBox(height: 20),
              Text(error!, style: TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int noUsuario;

  const HomeScreen({required this.noUsuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? qrResult;
  bool isLoading = false;

  Future<void> procesarQR(String codigo) async {
    final now = DateTime.now();
    final hora = DateFormat.Hm().format(now);
    final fecha = DateFormat('dd/MM/yyyy').format(now);

    final urlLista = Uri.parse(
        'https://api.sheety.co/b886748cc8aaf049fce079718ae15445/registrosQr/lista');
    final resLista = await http.get(urlLista);

    if (resLista.statusCode != 200) {
      _mostrarMensaje('Error al acceder a la hoja de asistencia');
      return;
    }

    final data = json.decode(resLista.body);
    final lista = data['lista'] as List;

    final fila = lista.firstWhere((e) => e['no'] == widget.noUsuario,
        orElse: () => null);

    if (fila == null) {
      _mostrarMensaje('No se encontró tu registro en la lista');
      return;
    }

    final id = fila['id'];
    final asistencia = fila['asistencia'];
    final horaEntrada = fila['horaEntrada'];
    final fechaActual = fila['fecha'];

    if (codigo == 'Entrada') {
      if (asistencia == 1 && fechaActual == fecha) {
        _mostrarMensaje('Ya registraste tu entrada hoy');
        return;
      }

      await http.put(
        Uri.parse(
            'https://api.sheety.co/b886748cc8aaf049fce079718ae15445/registrosQr/lista/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lista': {
            'asistencia': 1,
            'horaEntrada': hora,
            'fecha': fecha,
          }
        }),
      );

      _mostrarMensaje('Entrada registrada correctamente a las $hora');
    } else if (codigo == 'Salida') {
      if (asistencia != 1 || fechaActual != fecha) {
        _mostrarMensaje('Primero debes registrar tu entrada');
        return;
      }

      if (fila['horaSalida'] != '') {
        _mostrarMensaje('Ya registraste tu salida hoy');
        return;
      }

      await http.put(
        Uri.parse(
            'https://api.sheety.co/b886748cc8aaf049fce079718ae15445/registrosQr/lista/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lista': {
            'horaSalida': hora,
          }
        }),
      );

      _mostrarMensaje('Salida registrada correctamente a las $hora');
    } else {
      _mostrarMensaje('Código QR no válido');
    }
  }

  void _mostrarMensaje(String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Asistencia'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Aceptar'),
          )
        ],
      ),
    );
  }

  void _escanearQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRViewExample()),
    );

    if (result != null) {
      setState(() => isLoading = true);
      await procesarQR(result);
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usuario ${widget.noUsuario}'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _escanearQR,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Escanear QR'),
                  )
                ],
              ),
      ),
    );
  }
}

class QRViewExample extends StatefulWidget {
  @override
  State<QRViewExample> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanned = false;

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!scanned) {
        scanned = true;
        controller.pauseCamera();
        Navigator.pop(context, scanData.code);
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
