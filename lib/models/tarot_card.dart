/// Модель одной карты Таро (старший аркан).
class TarotCard {
  final int number;
  final String name;
  final String romanNumeral;
  final String keyMessage;
  final String fullText;
  final String yesNoText;

  const TarotCard({
    required this.number,
    required this.name,
    required this.romanNumeral,
    required this.keyMessage,
    required this.fullText,
    required this.yesNoText,
  });
}

/// Одна открытая карта в истории пользователя.
class CardHistoryEntry {
  final TarotCard card;
  final DateTime date;
  final String note;

  const CardHistoryEntry({required this.card, required this.date, this.note = ''});

  CardHistoryEntry copyWith({String? note}) => CardHistoryEntry(
        card: card,
        date: date,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'cardNumber': card.number,
        'date': date.toIso8601String(),
        'note': note,
      };

  static CardHistoryEntry fromJson(Map<String, dynamic> json, TarotCard card) {
    return CardHistoryEntry(
      card: card,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
    );
  }
}
