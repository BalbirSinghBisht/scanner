import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/vault_service.dart';

enum PinDialogMode {
  unlock,
  create,
  change,
}

class PinCodeDialog extends StatefulWidget {
  final PinDialogMode mode;

  const PinCodeDialog({
    super.key,
    this.mode = PinDialogMode.unlock,
  });

  /// Shows the dialog to unlock private folder. Returns true if unlocked.
  static Future<bool> showUnlock(BuildContext context) async {
    final isSet = await VaultService.instance.isPinSet();
    if (!context.mounted) return false;

    if (!isSet) {
      // First time: prompt to create PIN
      final created = await showCreate(context);
      return created;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PinCodeDialog(mode: PinDialogMode.unlock),
    );
    return result ?? false;
  }

  /// Shows the dialog to create a new PIN. Returns true if successfully created.
  static Future<bool> showCreate(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PinCodeDialog(mode: PinDialogMode.create),
    );
    return result ?? false;
  }

  /// Shows the dialog to change PIN. Returns true if successfully changed.
  static Future<bool> showChange(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PinCodeDialog(mode: PinDialogMode.change),
    );
    return result ?? false;
  }

  @override
  State<PinCodeDialog> createState() => _PinCodeDialogState();
}

class _PinCodeDialogState extends State<PinCodeDialog>
    with SingleTickerProviderStateMixin {
  final int _pinLength = 4;
  String _enteredPin = '';
  String _firstEnteredPin = ''; // for create mode
  String _oldPinForChange = ''; // for change mode
  int _step = 0; // 0 = first/unlock, 1 = confirm, etc.

  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= _pinLength) return;
    HapticFeedback.lightImpact();

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == _pinLength) {
      _handleCompletedPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _triggerShake(String error) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = error;
      _enteredPin = '';
    });
    await _shakeController.forward(from: 0.0);
  }

  Future<void> _handleCompletedPin() async {
    switch (widget.mode) {
      case PinDialogMode.unlock:
        final success = await VaultService.instance.verifyPin(_enteredPin);
        if (success) {
          HapticFeedback.mediumImpact();
          if (mounted) Navigator.of(context).pop(true);
        } else {
          _triggerShake('Incorrect PIN. Please try again.');
        }
        break;

      case PinDialogMode.create:
        if (_step == 0) {
          _firstEnteredPin = _enteredPin;
          setState(() {
            _step = 1;
            _enteredPin = '';
          });
        } else {
          if (_enteredPin == _firstEnteredPin) {
            await VaultService.instance.setPin(_enteredPin);
            HapticFeedback.mediumImpact();
            if (mounted) Navigator.of(context).pop(true);
          } else {
            await _triggerShake('PINs do not match. Try again.');
            setState(() {
              _step = 0;
              _firstEnteredPin = '';
              _enteredPin = '';
            });
          }
        }
        break;

      case PinDialogMode.change:
        if (_step == 0) {
          final valid = await VaultService.instance.verifyPin(_enteredPin);
          if (valid) {
            _oldPinForChange = _enteredPin;
            setState(() {
              _step = 1;
              _enteredPin = '';
            });
          } else {
            _triggerShake('Current PIN incorrect.');
          }
        } else if (_step == 1) {
          _firstEnteredPin = _enteredPin;
          setState(() {
            _step = 2;
            _enteredPin = '';
          });
        } else {
          if (_enteredPin == _firstEnteredPin) {
            await VaultService.instance.changePin(_oldPinForChange, _enteredPin);
            HapticFeedback.mediumImpact();
            if (mounted) Navigator.of(context).pop(true);
          } else {
            await _triggerShake('New PINs do not match. Try again.');
            setState(() {
              _step = 1;
              _firstEnteredPin = '';
              _enteredPin = '';
            });
          }
        }
        break;
    }
  }

  String get _title {
    switch (widget.mode) {
      case PinDialogMode.unlock:
        return 'Unlock Private Folder';
      case PinDialogMode.create:
        return _step == 0 ? 'Create Vault PIN' : 'Confirm Vault PIN';
      case PinDialogMode.change:
        if (_step == 0) return 'Enter Current PIN';
        if (_step == 1) return 'Enter New PIN';
        return 'Confirm New PIN';
    }
  }

  String get _subtitle {
    switch (widget.mode) {
      case PinDialogMode.unlock:
        return 'Enter your 4-digit PIN to access locked items';
      case PinDialogMode.create:
        return _step == 0
            ? 'Choose a 4-digit PIN to protect your private items'
            : 'Re-enter your 4-digit PIN to confirm';
      case PinDialogMode.change:
        if (_step == 0) return 'Verify your identity to proceed';
        if (_step == 1) return 'Choose your new 4-digit PIN';
        return 'Re-enter your new 4-digit PIN to confirm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: c.glassBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.textTertiary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Vault Lock Icon with glow
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [c.primary, c.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // PIN Dots Indicator with shake animation
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _shakeAnimation.value * (_shakeController.value < 0.5 ? 1 : -1),
                  0,
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? c.primary : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? c.primary : c.textTertiary.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: c.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: c.accentRose,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else
            const SizedBox(height: 14),

          const SizedBox(height: 12),

          // Numeric Keypad
          _buildKeypad(c),
        ],
      ),
    );
  }

  Widget _buildKeypad(AppThemeColors c) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], c),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], c),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], c),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel button
            SizedBox(
              width: 72,
              height: 72,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            _buildKeypadButton('0', c),
            // Backspace button
            SizedBox(
              width: 72,
              height: 72,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _onDeletePressed,
                child: Icon(
                  CupertinoIcons.delete_left,
                  color: c.textPrimary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, AppThemeColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, c)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, AppThemeColors c) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(36),
        color: c.surfaceGlass,
        onPressed: () => _onDigitPressed(digit),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.glassBorder, width: 0.6),
          ),
          alignment: Alignment.center,
          child: Text(
            digit,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

