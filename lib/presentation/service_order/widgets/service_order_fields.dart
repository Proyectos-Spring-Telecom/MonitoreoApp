import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import 'service_order_ui.dart';

InputDecoration serviceOrderInputDecoration({
  String? hint,
  String? suffix,
  String? errorText,
  String? helperText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.error, width: 1.2),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle:
        const TextStyle(color: ServiceOrderColors.hintText, fontSize: 16),
    suffixText: suffix,
    suffixStyle:
        const TextStyle(color: ServiceOrderColors.mutedText, fontSize: 14),
    errorText: errorText,
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 12.5),
    helperText: helperText,
    helperStyle:
        const TextStyle(color: ServiceOrderColors.hintText, fontSize: 12.5),
    filled: true,
    fillColor: ServiceOrderColors.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          const BorderSide(color: ServiceOrderColors.accent, width: 1.2),
    ),
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
  );
}

/// Leyenda para formularios con campos obligatorios.
class ServiceOrderRequiredLegend extends StatelessWidget {
  const ServiceOrderRequiredLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Los campos marcados con '),
          TextSpan(
            text: '*',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' son obligatorios.'),
        ],
      ),
      style: TextStyle(color: ServiceOrderColors.mutedText, fontSize: 13),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const _FieldLabel(this.label, {this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ServiceOrderTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? minLines;
  final bool isLast;
  final bool isRequired;
  final String? errorText;
  final bool enabled;

  const ServiceOrderTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.isLast = false,
    this.isRequired = false,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines > 1;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, isRequired: isRequired),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: isMultiline ? TextInputType.multiline : keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            minLines: minLines,
            textInputAction: isMultiline
                ? TextInputAction.newline
                : (isLast ? TextInputAction.done : TextInputAction.next),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: serviceOrderInputDecoration(
              hint: hint,
              suffix: suffix,
              errorText: errorText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de selección con búsqueda: al tocarlo abre un panel con un buscador
/// y la lista filtrada.
class ServiceOrderDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final bool isLast;
  final bool isRequired;
  final String? errorText;
  final String? helperText;

  /// Texto visible de cada valor (p. ej. el nombre de un id de catálogo).
  final String Function(String value)? itemLabel;

  /// Agrega una primera opción que limpia la selección.
  final String? clearLabel;

  const ServiceOrderDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isLast = false,
    this.isRequired = false,
    this.errorText,
    this.helperText,
    this.itemLabel,
    this.clearLabel,
  });

  String _labelOf(String item) => itemLabel?.call(item) ?? item;

  Future<void> _openSearch(BuildContext context) async {
    final change = onChanged;
    if (change == null) return;
    FocusScope.of(context).unfocus();
    final selection = await showModalBottomSheet<_DropdownSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ServiceOrderColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SearchableListSheet(
        title: label,
        items: items,
        selected: value,
        labelOf: _labelOf,
        clearLabel: clearLabel,
      ),
    );
    if (selection != null) change(selection.value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final selected = value != null && items.contains(value) ? value : null;
    final isLocked = !enabled && selected != null;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(label, isRequired: isRequired),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => _openSearch(context) : null,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: selected == null,
                decoration: serviceOrderInputDecoration(
                  errorText: errorText,
                  helperText: helperText,
                ).copyWith(
                  enabled: enabled,
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
                  suffixIcon: Icon(
                    isLocked ? Icons.lock_outline : Icons.keyboard_arrow_down,
                    size: isLocked ? 20 : 24,
                    color: enabled || isLocked
                        ? ServiceOrderColors.mutedText
                        : ServiceOrderColors.hintText,
                  ),
                ),
                child: Text(
                  selected == null ? hint : _labelOf(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected == null
                        ? ServiceOrderColors.hintText
                        : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resultado del panel: [value] `null` significa "limpiar selección".
class _DropdownSelection {
  final String? value;

  const _DropdownSelection(this.value);
}

class _SearchableListSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final String Function(String item) labelOf;
  final String? clearLabel;

  const _SearchableListSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.clearLabel,
  });

  @override
  State<_SearchableListSheet> createState() => _SearchableListSheetState();
}

class _SearchableListSheetState extends State<_SearchableListSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  static const Map<String, String> _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  static String _normalize(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().trim();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query);
    final results = query.isEmpty
        ? widget.items
        : widget.items
            .where((item) => _normalize(widget.labelOf(item)).contains(query))
            .toList();
    final showClear =
        widget.clearLabel != null && widget.selected != null && query.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ServiceOrderColors.tile,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                autofocus: widget.items.length > 8,
                onChanged: (text) => setState(() => _query = text),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration:
                    serviceOrderInputDecoration(hint: 'Buscar...').copyWith(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: ServiceOrderColors.mutedText,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: ServiceOrderColors.mutedText,
                            size: 20,
                          ),
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const Divider(height: 1, color: ServiceOrderColors.divider),
            Expanded(
              child: results.isEmpty && !showClear
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(
                            color: ServiceOrderColors.hintText,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        if (showClear)
                          _OptionTile(
                            label: widget.clearLabel!,
                            muted: true,
                            onTap: () => Navigator.of(context)
                                .pop(const _DropdownSelection(null)),
                          ),
                        for (final item in results)
                          _OptionTile(
                            label: widget.labelOf(item),
                            selected: item == widget.selected,
                            onTap: () => Navigator.of(context)
                                .pop(_DropdownSelection(item)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: selected ? ServiceOrderColors.accentBackground : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: muted
                      ? ServiceOrderColors.hintText
                      : (selected
                          ? Colors.white
                          : ServiceOrderColors.mutedText),
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check,
                  color: ServiceOrderColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
