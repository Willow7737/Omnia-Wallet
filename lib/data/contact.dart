import 'dart:convert';

/// A saved recipient — a labelled Omnia DID in the local address book.
class Contact {
  const Contact({required this.label, required this.did});

  final String label;
  final String did;

  Map<String, dynamic> toJson() => {'label': label, 'did': did};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        label: json['label'] as String? ?? '',
        did: json['did'] as String? ?? '',
      );

  Contact copyWith({String? label, String? did}) =>
      Contact(label: label ?? this.label, did: did ?? this.did);

  static String encodeList(List<Contact> contacts) =>
      jsonEncode(contacts.map((c) => c.toJson()).toList());

  static List<Contact> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(Contact.fromJson)
          .where((c) => c.did.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
