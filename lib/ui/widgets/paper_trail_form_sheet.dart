import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../models/paper_trail_doc.dart';
import '../../services/paper_trail_service.dart';

class PaperTrailFormSheet extends StatefulWidget {
  final MediaItem item;
  final PaperTrailDoc? existingDoc;

  const PaperTrailFormSheet({
    super.key,
    required this.item,
    this.existingDoc,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaItem item,
    PaperTrailDoc? existingDoc,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaperTrailFormSheet(
        item: item,
        existingDoc: existingDoc,
      ),
    );
  }

  @override
  State<PaperTrailFormSheet> createState() => _PaperTrailFormSheetState();
}

class _PaperTrailFormSheetState extends State<PaperTrailFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _storeController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  String _category = 'Electronics';
  String _currency = '\$';
  DateTime _purchaseDate = DateTime.now();
  DateTime? _warrantyExpiryDate;
  int _selectedPresetMonths = 12; // 1 year default

  final List<String> _categories = [
    'Electronics',
    'Appliances',
    'Vehicles',
    'Home & Tools',
    'Health & Medical',
    'Fashion & Jewelry',
    'General Receipt',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final doc = widget.existingDoc;
    if (doc != null) {
      _titleController = TextEditingController(text: doc.title);
      _storeController = TextEditingController(text: doc.storeName ?? '');
      _amountController = TextEditingController(
          text: doc.amount != null ? doc.amount!.toStringAsFixed(2) : '');
      _notesController = TextEditingController(text: doc.notes ?? '');
      _category = doc.category;
      _currency = doc.currency;
      _purchaseDate = doc.purchaseDate;
      _warrantyExpiryDate = doc.warrantyExpiryDate;
    } else {
      _titleController = TextEditingController(
        text: widget.item.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      );
      _storeController = TextEditingController();
      _amountController = TextEditingController();
      _notesController = TextEditingController();
      _purchaseDate = widget.item.createdAt;
      _warrantyExpiryDate = _purchaseDate.add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyWarrantyPreset(int months) {
    setState(() {
      _selectedPresetMonths = months;
      if (months == 0) {
        _warrantyExpiryDate = null;
      } else {
        _warrantyExpiryDate = DateTime(
          _purchaseDate.year,
          _purchaseDate.month + months,
          _purchaseDate.day,
        );
      }
    });
  }

  Future<void> _pickDate({required bool isPurchase}) async {
    final initial = isPurchase ? _purchaseDate : (_warrantyExpiryDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.colors(context).primary,
              surface: const Color(0xFF1E1E24),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
          if (_selectedPresetMonths > 0) {
            _warrantyExpiryDate = DateTime(
              picked.year,
              picked.month + _selectedPresetMonths,
              picked.day,
            );
          }
        } else {
          _warrantyExpiryDate = picked;
          _selectedPresetMonths = -1; // custom
        }
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final amountVal = double.tryParse(_amountController.text.trim());
    final docId = widget.existingDoc?.id ??
        'doc_${widget.item.localId}_${DateTime.now().millisecondsSinceEpoch}';

    final doc = PaperTrailDoc(
      id: docId,
      localId: widget.item.localId,
      title: title,
      category: _category,
      purchaseDate: _purchaseDate,
      warrantyExpiryDate: _warrantyExpiryDate,
      amount: amountVal,
      currency: _currency,
      storeName: _storeController.text.trim().isEmpty ? null : _storeController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.existingDoc?.createdAt ?? DateTime.now(),
    );

    await PaperTrailService.instance.saveDoc(doc);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${doc.title}" to Paper Trail'),
          backgroundColor: AppTheme.colors(context).surfaceElevated,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final df = DateFormat('MMM d, yyyy');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xF51C1C1E) : const Color(0xF8FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: c.glassBorderSubtle, width: 0.5),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.textTertiary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: c.accentTeal.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.receipt_long, color: c.accentTeal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.existingDoc == null
                              ? 'Track in Paper Trail'
                              : 'Edit Warranty Details',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      onPressed: _save,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Document Title
                _buildFieldLabel('ITEM / DOCUMENT TITLE', c),
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: c.textPrimary, fontSize: 15),
                  decoration: _buildInputDecoration('e.g. Sony WH-1000XM5, Dishwasher', c),
                ),
                const SizedBox(height: 14),

                // Category & Store row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('CATEGORY', c),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: c.isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.glassBorderSubtle, width: 0.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _category,
                                isExpanded: true,
                                dropdownColor: c.surfaceElevated,
                                icon: Icon(CupertinoIcons.chevron_down, size: 14, color: c.textSecondary),
                                style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                                items: _categories.map((cat) {
                                  return DropdownMenuItem(value: cat, child: Text(cat));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _category = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('STORE / SELLER', c),
                          TextField(
                            controller: _storeController,
                            style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                            decoration: _buildInputDecoration('e.g. Amazon, Apple', c),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Amount & Purchase Date row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('PRICE / AMOUNT', c),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                            decoration: _buildInputDecoration('0.00', c, prefix: '$_currency '),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('PURCHASE DATE', c),
                          InkWell(
                            onTap: () => _pickDate(isPurchase: true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: c.isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.glassBorderSubtle, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.calendar, size: 14, color: c.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    df.format(_purchaseDate),
                                    style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Warranty Presets
                _buildFieldLabel('WARRANTY DURATION', c),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPresetChip('None (Receipt)', 0, c),
                      _buildPresetChip('30 Days Return', 1, c),
                      _buildPresetChip('6 Months', 6, c),
                      _buildPresetChip('1 Year', 12, c),
                      _buildPresetChip('2 Years', 24, c),
                      _buildPresetChip('3 Years', 36, c),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Custom Warranty Expiration Date Selector
                InkWell(
                  onTap: () => _pickDate(isPurchase: false),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _warrantyExpiryDate != null ? c.accentTeal.withOpacity(0.4) : c.glassBorderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.shield_fill,
                          size: 16,
                          color: _warrantyExpiryDate != null ? c.accentTeal : c.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _warrantyExpiryDate != null
                                  ? 'Warranty valid until ${df.format(_warrantyExpiryDate!)}'
                                  : 'No warranty expiration set',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Tap to pick a custom warranty end date',
                              style: TextStyle(color: c.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(CupertinoIcons.chevron_right, size: 13, color: c.textTertiary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                _buildFieldLabel('NOTES / SERIAL NUMBER', c),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: _buildInputDecoration('e.g. Serial: SN9824X, Extended AppleCare+', c),
                ),
                const SizedBox(height: 20),

                // Delete button if editing
                if (widget.existingDoc != null)
                  Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        await PaperTrailService.instance.deleteDoc(widget.existingDoc!.id);
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: Text(
                        'Remove from Paper Trail',
                        style: TextStyle(color: c.accentRose, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, AppThemeColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, AppThemeColors c, {String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      prefixStyle: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
      filled: true,
      fillColor: c.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.glassBorderSubtle, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.glassBorderSubtle, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.2),
      ),
    );
  }

  Widget _buildPresetChip(String label, int months, AppThemeColors c) {
    final isSelected = _selectedPresetMonths == months;
    return GestureDetector(
      onTap: () => _applyWarrantyPreset(months),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? c.primary
              : (c.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorderSubtle,
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : c.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

