import 'package:flutter/material.dart';

import '../models/spending_card_style.dart';

class SpendingCardCustomizer extends StatelessWidget {
  const SpendingCardCustomizer({
    super.key,
    required this.character,
    required this.cardColor,
    required this.onCharacterChanged,
    required this.onColorChanged,
    this.enabled = true,
  });

  final SpendingCardCharacter character;
  final SpendingCardColor? cardColor;
  final ValueChanged<SpendingCardCharacter> onCharacterChanged;
  final ValueChanged<SpendingCardColor> onColorChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Karakter VIP', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in SpendingCardCharacter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    selected: character == option,
                    button: true,
                    label: option.label,
                    child: Material(
                      color: character == option
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: enabled
                            ? () => onCharacterChanged(option)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Image.asset(
                                option.asset ??
                                    'assets/mascot/jajanku_mascot.png',
                                width: 60,
                                height: 60,
                                cacheWidth: 180,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(height: 4),
                              Text(option.label),
                              Icon(
                                character == option
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Warna gambar', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 0,
          runSpacing: 4,
          children: [
            for (final option in SpendingCardColor.values)
              Semantics(
                label: option.label,
                button: true,
                enabled: enabled,
                selected: (cardColor ?? SpendingCardColor.orange) == option,
                child: Tooltip(
                  message: option.label,
                  excludeFromSemantics: true,
                  child: InkResponse(
                    onTap: enabled ? () => onColorChanged(option) : null,
                    radius: 24,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: option.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  (cardColor ?? SpendingCardColor.orange) ==
                                      option
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child:
                              (cardColor ?? SpendingCardColor.orange) == option
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
