import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class CblWebSocket {
  late WebSocketChannel _channel;
  late StreamSubscription<dynamic> _streamSubscription;

  String? _url;
  String? _username;
  String? _password;
  String? _scope;
  String? _collections;

  Stream<dynamic> connect(
      {required String url,
      required String username,
      required String password}) {
    _url = url;
    _username = username;
    _password = password;
    print('Websocket connected');
    RegExp regex = RegExp(r'^(ws|wss)://');
    String modifiedUrl = url.replaceFirstMapped(regex, (match) {
      return '${match.group(1)}://$username:$password@';
    });

    final wsUrl = Uri.parse(
        '$modifiedUrl.$_scope.$_collections/_changes?feed=websocket&include_docs=true');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel.sink.add('{"include_docs":true}');

    return _channel.stream;
  }

  void createCollection(String collection, String scope) {
    _collections = collection;
    _scope = scope;
  }

  void startListening(void Function(dynamic) handleMessage) {
    _streamSubscription = _channel.stream.listen((msg) {
      handleMessage.call(msg);
    });
  }

  void stopListening() {
    _streamSubscription.cancel();
  }

  void disconnect() {
    _streamSubscription.cancel();
    _channel.sink.close();
  }

  String _generateRandomString(int length) {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> saveDocument(Map<String, Object> map) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$_username:$_password'))}'
      };

      print('${base64Encode(utf8.encode('$_username:$_password'))}');

      String? baseUrl;

      final regex = RegExp(r'^ws://([\w\-.]+)(:\d+)?(/[^\/?]+)?');
      final Match? match = regex.firstMatch(_url ?? '');

      if (match != null) {
        baseUrl =
            'http://${match.group(1)}:4984${match.group(3) ?? ''}.$_scope.$_collections';
      } else {
        print('Invalid WebSocket URL');
      }

      print('$baseUrl/${_generateRandomString(10)}');

      final request = http.Request(
          'PUT', Uri.parse('$baseUrl/${_generateRandomString(10)}'));

      request.body = json.encode(map);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        print(await response.stream.bytesToString());
      } else {
        print(response.reasonPhrase);
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
