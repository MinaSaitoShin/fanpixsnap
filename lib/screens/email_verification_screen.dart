import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email; // SignUpScreen から受け取るメールアドレス

  EmailVerificationScreen({required this.email});

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  final supabase = Supabase.instance.client;

  // メール認証（確認コード入力）
  Future<void> _confirmEmail() async {
    setState(() => _errorMessage = '');
    if (_tokenController.text.isEmpty) {
      setState(() => _errorMessage = "認証コードを入力してください");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: widget.email,
        token: _tokenController.text.trim(),
      );

      if (response.error != null) {
        setState(() => _errorMessage = response.error!.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("メール認証が完了しました！ログインしてください")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = "認証に失敗しました。もう一度お試しください。");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 確認メールの再送信
  Future<void> _resendConfirmationEmail() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = '');

    try {
      final response = await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (response.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("認証メールを再送しました。受信トレイを確認してください")),
        );
      } else {
        setState(() => _errorMessage = response.error!.message);
      }
    } catch (e) {
      print("再送信に失敗しました。もう一度お試しください。$e");
      setState(() => _errorMessage = "再送信に失敗しました。時間をおいてからもう一度お試しください。");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("メール認証")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("認証コードを入力してください"),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(labelText: "認証コード"),
            ),
            SizedBox(height: 10),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            if (_isLoading)
              CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: _confirmEmail,
                child: Text("認証コードを確認"),
              ),
              ElevatedButton(
                onPressed: _resendConfirmationEmail,
                child: Text("認証メールを再送"),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                  );
                },
                child: Text(
                  "ユーザ新規登録画面に戻る",
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on AuthResponse {
  get error => null;
}

extension on ResendResponse {
  get error => null;
}
