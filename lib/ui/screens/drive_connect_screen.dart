import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class DriveConnectScreen extends StatefulWidget {
  const DriveConnectScreen({super.key});

  @override
  State<DriveConnectScreen> createState() => _DriveConnectScreenState();
}

class _DriveConnectScreenState extends State<DriveConnectScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  bool _showAdvancedConfig = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _clientIdController.text = authProvider.customClientId ?? '';
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Drive Icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryAccent, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.add_to_drive_rounded,
                    size: 38,
                    color: AppTheme.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  auth.isAuthenticated ? 'Google Account Connected' : 'Connect Your Google Drive',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  auth.isAuthenticated
                      ? 'Authenticated for direct cloud backups'
                      : 'Sign in with your Google account to back up photos and videos to your Drive storage.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Account Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: auth.isAuthenticated
                        ? AppTheme.emeraldGreen
                        : AppTheme.darkCardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: auth.isAuthenticated
                              ? AppTheme.emeraldGreen.withOpacity(0.2)
                              : Colors.white10,
                          child: Icon(
                            auth.isAuthenticated ? Icons.person : Icons.cloud_off,
                            color: auth.isAuthenticated
                                ? AppTheme.emeraldGreen
                                : Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.isAuthenticated
                                    ? (auth.userDisplayName ?? 'Google User')
                                    : 'Not Connected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.isAuthenticated
                                    ? (auth.userEmail ?? '')
                                    : 'No account currently authenticated',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (auth.isAuthenticated
                                    ? AppTheme.emeraldGreen
                                    : Colors.grey)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            auth.isAuthenticated ? 'Active' : 'Offline',
                            style: TextStyle(
                              color: auth.isAuthenticated
                                  ? AppTheme.emeraldGreen
                                  : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (auth.isAuthenticated) ...[
                      const Divider(height: 24),
                      _detailRow('Target Scope', 'drive.file (App-managed only)'),
                      _detailRow('Storage Quota', 'Account Direct Storage (5 TB)'),
                      _detailRow('Upload Destination', 'PhoneBackup/Photos & Videos'),
                    ],
                  ],
                ),
              ),

              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.roseDanger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.roseDanger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.roseDanger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.roseDanger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: auth.clearError,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action Buttons
              if (!auth.isAuthenticated) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: auth.isLoading ? null : () => auth.signIn(),
                    icon: auth.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Connect Google Drive Account'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.isLoading ? null : () => auth.signIn(),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Switch Google Account'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.roseDanger,
                    ),
                    onPressed: auth.isLoading ? null : () => auth.disconnect(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnect Account'),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Advanced OAuth Configuration Toggle (Optional Client ID)
              InkWell(
                onTap: () => setState(() => _showAdvancedConfig = !_showAdvancedConfig),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvancedConfig
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        color: Colors.white70,
                      ),
                      const Text(
                        'Developer OAuth Client Configuration (Optional)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showAdvancedConfig) ...[
                const SizedBox(height: 8),
                Text(
                  'Enter a custom OAuth 2.0 Client ID for your testing environment if not using the default native client bundle.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'OAuth 2.0 Client ID (Web/Desktop)',
                    hintText: 'e.g. 123456789-abc.apps.googleusercontent.com',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      auth.setCustomClientId(
                        _clientIdController.text.trim().isNotEmpty
                            ? _clientIdController.text.trim()
                            : null,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Client ID configuration saved')),
                      );
                    },
                    child: const Text('Save Client ID'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
