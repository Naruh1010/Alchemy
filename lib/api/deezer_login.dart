import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:alchemy/api/deezer.dart';
import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;

import '../utils/cookie_manager.dart';
import '../utils/env.dart';

class DeezerLogin {
  static final Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36',
    'X-User-IP': '1.1.1.1',
    'x-deezer-client-ip': '1.1.1.1',
    'Accept': '*/*'
  };
  static final cookieManager = CookieManager();

  static Future<KeyBag?> signInWithEmail(String email, String password) async {
    final apiKey = Env.deezerGatewayAPI;
    final apiSecret = Env.deezerMobileKey;

    StringBuffer sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      sb.write(Random().nextInt(16).toRadixString(16));
    }

    Uri tokenRequestUri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': apiKey,
      'method': 'mobile_auth',
      'output': '3',
      'uniq_id': sb.toString()
    });

    http.Response tokenResponse =
        await http.get(tokenRequestUri).catchError((e) {
      return http.Response('', 200);
    });

    String? token = jsonDecode(tokenResponse.body)['results']['TOKEN'];

    if (token == null) return null;

    Key initKeyBytes = Key(utf8.encode(apiSecret));
    Encrypter keyEncrypter =
        Encrypter(AES(initKeyBytes, mode: AESMode.ecb, padding: null));

    String keyBag = keyEncrypter.decrypt(Encrypted.fromBase16(token));

    String keyBagToken = keyBag.substring(0, 64);
    String keyBagTokenKey = keyBag.substring(64, 80);
    String keyBagUserKey = keyBag.substring(80, 96);

    Key tokenKeyBytes = Key(utf8.encode(keyBagTokenKey));
    Encrypter encrypter =
        Encrypter(AES(tokenKeyBytes, mode: AESMode.ecb, padding: null));
    Encrypted cipheredToken = encrypter.encrypt(keyBagToken);
    String authToken = cipheredToken.base16;

    Uri tokenAuthUri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'method': 'api_checkToken',
      'output': '3',
      'api_key': apiKey,
      'auth_token': authToken
    });

    http.Response tokenAuthResponse =
        await http.get(tokenAuthUri).catchError((e) {
      return http.Response('', 200);
    });

    String? sid = jsonDecode(tokenAuthResponse.body)['results'];

    if (sid == null) return null;

    Uint8List passwordBytes = utf8.encode(password);
    Key userKey = Key(utf8.encode(keyBagUserKey));

    int bytesToPad = 16 - (passwordBytes.length % 16);
    Uint8List paddedPlaintextBytes =
        Uint8List(passwordBytes.length + bytesToPad);
    paddedPlaintextBytes.setRange(0, passwordBytes.length, passwordBytes);

    Encrypter passwordEncrypter = Encrypter(AES(userKey,
            mode: AESMode.ecb,
            padding: null) // Use ECB mode and disable automatic padding
        );
    Encrypted encryptedData =
        passwordEncrypter.encryptBytes(paddedPlaintextBytes);
    String cipheredPassword = encryptedData.base16;

    Uri authUri = Uri.https('api.deezer.com', '/1.0/gateway.php', {
      'api_key': apiKey,
      'output': '3',
      'input': '3',
      'method': 'mobile_userAuth',
      'sid': sid
    });

    Map<String, String> authData = {
      'mail': email,
      'password': cipheredPassword,
    };

    Map<String, String> headers = {
      'User-Agent': '',
      'Content-Type': 'text/plain;charset=UTF-8',
      'origin': 'https://www.deezer.com',
      'Cache-Control': 'max-age=0',
      'Accept': '*/*',
      'Accept-Charset': 'utf-8,ISO-8859-1;q=0.7,*;q=0.3',
      'Connection': 'keep-alive',
      'sec-fetch-site': 'same-origin',
      'sec-fetch-mode': 'same-origin',
      'sec-fetch-dest': 'empty',
      'referer': 'https://www.deezer.com/',
    };

    http.Response authRequest = await http
        .post(authUri, headers: headers, body: jsonEncode(authData))
        .catchError((e) {
      return http.Response('', 200);
    });

    Map<String, dynamic> authResponse = jsonDecode(authRequest.body);

    if (authResponse['error'] != null && authResponse['error'].isNotEmpty) {
      throw DeezerLoginException(
          authResponse.keys.first, authResponse[authResponse.keys.first]);
    }

    String? arl = authResponse['results']['ARL'];
    String? userToken = authResponse['results']['USER_TOKEN'];

    KeyBag k = KeyBag(
      token: userToken,
      tokenKey: keyBagTokenKey,
      userKey: keyBagUserKey,
      sid: sid,
      arl: arl,
    );

    return k;
  }
}

class DeezerLoginException implements Exception {
  final String type;
  final dynamic message;

  DeezerLoginException(this.type, [this.message]);

  @override
  String toString() {
    if (message == null) {
      return 'DeezerLoginException: $type';
    } else {
      return 'DeezerLoginException: $type\nCaused by: $message';
    }
  }
}
