import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openid_client/openid_client.dart';
import 'package:openid_client/openid_client_io.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String _clientId = 'NMS_Mobile';
  static const String _issuer = 'https://apinpm.egov.phutho.vn';
  final String _redirectUri = 'com.yourapp://callback';
  final List<String> _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    'NMS'
  ];

  String? accessToken;
  String? logoutUrl;

  @override
  void initState() {
    super.initState();
    _loadSession(); // Kiểm tra phiên đăng nhập hiện tại
  }

  // Kiểm tra và tải token từ bộ nhớ đệm
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('accessToken');
    String? logout = prefs.getString('logoutUrl');
    if (token != null) {
      setState(() {
        accessToken = token;
        logoutUrl = logout;
      });
      debugPrint('Đã tìm thấy phiên đăng nhập: $token');
    }
  }

  // Lưu session vào SharedPreferences
  Future<void> _saveSession(String token, String logout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
    await prefs.setString('logoutUrl', logout);
  }

  // Xóa session khỏi SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('logoutUrl');
    setState(() {
      accessToken = null;
      logoutUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Trang Chủ")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: Text("Đăng Nhập"),
              onPressed: _performAuthentication, // Gọi phương thức _performAuthentication
            ),
            if (accessToken != null)
              Text("Đã đăng nhập: ${accessToken!.substring(0, 10)}..."),
            ElevatedButton(
              child: Text("Đăng Xuất"),
              onPressed: logout,
            ),
            ElevatedButton(
              child: Text("Gọi API"),
              onPressed: _callApi,
            ),
          ],
        ),
      ),
    );
  }

  // Hàm gửi yêu cầu POST tới token endpoint để lấy access token
  Future<void> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://apinpm.egov.phutho.vn/connect/token'),  // Địa chỉ token endpoint
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': _clientId,
          // 'client_secret': 'your_client_secret', // Nếu có
        },
      );

      if (response.statusCode == 200) {
        // Phản hồi thành công, lấy access token
        final Map<String, dynamic> data = json.decode(response.body);
        final String accessToken = data['access_token'];
        final String refreshToken = data['refresh_token'];
        final int expiresIn = data['expires_in'];

        debugPrint('Token nhận được: $accessToken');
        debugPrint('Refresh Token: $refreshToken');
        debugPrint('Hạn sử dụng token: $expiresIn giây');

        // Lưu thông tin session
        await _saveSession(accessToken, refreshToken);

        // Cập nhật trạng thái UI
        setState(() {
          this.accessToken = accessToken;
          // Bạn có thể lưu refresh token nếu cần thiết cho việc làm mới token
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lấy Access Token thành công')),
        );
      } else {
        debugPrint('Lỗi từ server: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lấy token: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi token endpoint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gọi token endpoint: $e')),
      );
    }
  }

  // Hàm gọi API sử dụng access token đã lưu
  Future<void> _callApi() async {
    if (accessToken == null) {
      debugPrint('Không có access token');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://apinpm.egov.phutho.vn/api/app/chuong-trinh/3a16e986-ece8-dbbd-84b5-749371bd2284'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Dữ liệu từ API: $data');
      } else {
        debugPrint('Lỗi khi gọi API: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi gọi API: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gọi API: $e')),
      );
    }
  }

  // Phương thức thực hiện quá trình đăng nhập
  Future<void> _performAuthentication() async {
    if (accessToken != null) {
      debugPrint('Người dùng đã đăng nhập. Bỏ qua đăng nhập lại.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn đã đăng nhập trước đó')),
      );
      return;
    }

    try {
      debugPrint('Bắt đầu quá trình đăng nhập');

      // Khám phá issuer
      var issuer = await Issuer.discover(Uri.parse(_issuer));
      debugPrint('Issuer được khám phá: ${issuer.metadata.issuer}');

      // Tạo client
      var client = Client(issuer, _clientId);

      // Tạo authenticator
      var authenticator = Authenticator(
        client,
        scopes: _scopes,
        redirectUri: Uri.parse(_redirectUri),
        urlLancher: (url) async {
          debugPrint('Đang mở URL: $url');
          try {
            final result = await FlutterWebAuth2.authenticate(
              url: url,
              callbackUrlScheme: 'com.yourapp',
            );
            debugPrint('Kết quả xác thực: $result');
            return result;
          } catch (e) {
            if (e is PlatformException && e.code == 'CANCELED') {
              debugPrint('Người dùng đã hủy đăng nhập');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bạn đã hủy đăng nhập'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              debugPrint('Lỗi khác: $e');
              rethrow;
            }
          }
        },
      );

      // Thực hiện authorize
      var credential = await authenticator.authorize();

      // Lấy token response
      var tokenResponse = await credential.getTokenResponse();

      // Lưu token và logout URL
      await _saveSession(tokenResponse.accessToken!, credential.generateLogoutUrl().toString());

      setState(() {
        accessToken = tokenResponse.accessToken;
        logoutUrl = credential.generateLogoutUrl().toString();
      });

      debugPrint('Đăng nhập thành công');
      debugPrint('Access Token: $accessToken');
      debugPrint('Logout URL: $logoutUrl');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập thành công')),
      );
    } catch (e, stackTrace) {
      debugPrint('Lỗi chi tiết: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi khi đăng nhập')),
      );
    }
  }

  // Hàm đăng xuất
  Future<void> logout() async {
    if (logoutUrl != null) {
      try {
        await FlutterWebAuth2.authenticate(
          url: logoutUrl!,
          callbackUrlScheme: 'com.yourapp',
        );
        await _clearSession();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng xuất thành công')),
        );
      } catch (e) {
        debugPrint('Lỗi đăng xuất: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
