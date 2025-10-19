import 'package:flutter/material.dart';
import 'package:flutter_flappy_bird/game.dart';

class UpdateAccountOverlay extends StatefulWidget {
  final FlappyBirdGame game;
  const UpdateAccountOverlay({super.key, required this.game});

  @override
  State<UpdateAccountOverlay> createState() => _UpdateAccountOverlayState();
}

class _UpdateAccountOverlayState extends State<UpdateAccountOverlay> {
  final _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndSetCurrentUsername();
  }

  Future<void> _fetchAndSetCurrentUsername() async {
    final client = widget.game.nakamaManager.client;
    final session = widget.game.nakamaManager.session;
    if (client == null || session == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final account = await client.getAccount(session);
      final currentName =
          account.user.displayName ?? account.user.username ?? '';
      if (mounted) _controller.text = currentName;
    } catch (e) {
      debugPrint('[UpdateAccount] Error fetching: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUsername() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.game.nakamaManager.updateUsername(newName);
      _updateAccountInfoDisplay(newName);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[UpdateAccount] Failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Cập nhật AccountInfo trong MenuScene
  void _updateAccountInfoDisplay(String newName) {
    final currentScene = widget.game.sceneManager.currentScene;
    if (currentScene == null ||
        !currentScene.toString().contains('MenuScene')) {
      return;
    }

    try {
      final menuScene = currentScene as dynamic;
      menuScene.accountInfo?.updateName(newName);
      debugPrint('[UpdateAccount] Updated display');
    } catch (e) {
      debugPrint('[UpdateAccount] Could not update display: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF023E8A), Color(0xFF0096C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _isLoading ? _buildLoading() : _buildTextField(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // Header với title và close button
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Đổi Tên',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // Loading indicator
  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  // Text field nhập tên
  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        prefixIcon: const Icon(Icons.person, color: Colors.white70),
        hintText: 'Nhập tên mới...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Save button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateUsername,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B4D8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                'LƯU THAY ĐỔI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
