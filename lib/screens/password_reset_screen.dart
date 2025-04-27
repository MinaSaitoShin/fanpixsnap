import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _recoverSessionFromLink();
  }

  Future<void> _recoverSessionFromLink() async {
    final uri = Uri.base;
    final accessToken = uri.queryParameters['access_token'];

    if (accessToken != null) {
      final response = await supabase.auth.setSession(accessToken);

      if (response.user == null) {
        print('セッション復元に失敗');
      } else {
        print('セッション復元成功: ${response.user!.id}');
      }
    } else {
      print('リンクにaccess_tokenがありません');
    }
  }

  Future<void> _changePassword() async {
    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('パスワード変更成功！')),
        );
        Navigator.popUntil(context, (route) => route.isFirst); // ホームに戻るなど
      } else {
        throw Exception('パスワード変更に失敗');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('新しいパスワード入力')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "新しいパスワード"),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text('パスワード変更'),
            )
          ],
        ),
      ),
    );
  }
}
