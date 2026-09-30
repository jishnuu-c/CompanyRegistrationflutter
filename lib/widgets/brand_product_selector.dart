import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BrandProductSelector extends StatefulWidget {
  final String title;
  final String searchHint;
  final String addHint;
  final List<String> allItems;
  final List<String> selectedItems;
  final ValueChanged<List<String>> onSelectionChanged;
  final ValueChanged<String> onAddNewItem;

  const BrandProductSelector({
    super.key,
    required this.title,
    required this.searchHint,
    required this.addHint,
    required this.allItems,
    required this.selectedItems,
    required this.onSelectionChanged,
    required this.onAddNewItem,
  });

  @override
  State<BrandProductSelector> createState() => _BrandProductSelectorState();
}

class _BrandProductSelectorState extends State<BrandProductSelector> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      widget.onAddNewItem(text);
      if (!widget.selectedItems.contains(text)) {
        final updated = List<String>.from(widget.selectedItems)..add(text);
        widget.onSelectionChanged(updated);
      }
      _addController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.toLowerCase().contains(_searchQuery);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.inputBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input box at the top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: GoogleFonts.outfit(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),

          // Scrollable Checkbox list
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 130),
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'No matches found',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isChecked = widget.selectedItems.contains(item);

                      return InkWell(
                        onTap: () {
                          final updated = List<String>.from(widget.selectedItems);
                          if (isChecked) {
                            updated.remove(item);
                          } else {
                            updated.add(item);
                          }
                          widget.onSelectionChanged(updated);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: isChecked,
                                  activeColor: AppTheme.buttonNavy,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade600, width: 1.2),
                                  onChanged: (val) {
                                    final updated = List<String>.from(widget.selectedItems);
                                    if (val == true) {
                                      if (!updated.contains(item)) updated.add(item);
                                    } else {
                                      updated.remove(item);
                                    }
                                    widget.onSelectionChanged(updated);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                    color: isChecked ? AppTheme.primaryNavy : AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Add new item row at the bottom
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: TextField(
                      controller: _addController,
                      onSubmitted: (_) => _handleAdd(),
                      decoration: InputDecoration(
                        hintText: widget.addHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        hintStyle: GoogleFonts.outfit(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _handleAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
