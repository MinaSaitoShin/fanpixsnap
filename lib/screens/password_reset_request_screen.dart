import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetRequestScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("パスワードリセット用のメールを送信しました")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラー: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('パスワードリセットメール送信')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "メールアドレス"),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _sendPasswordResetEmail(context),
              child: Text('リセットメール送信'),
            )
          ],
        ),
      ),
    );
  }
}
