import 'package:flutter/material.dart';

class SuccessPage extends StatelessWidget {
  final String authCode;

  SuccessPage({required this.authCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Đăng Nhập Thành Công"),
      ),
      body: Center(
        child: Text("Mã xác thực: $authCode"),
      ),
    );
  }
}
