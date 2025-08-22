import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CalendarEventModel {
  final String? id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String tag; // NOVO: Campo para a tag do evento

  CalendarEventModel({
    this.id,
    required this.title,
    this.description = '',
    required this.start,
    required this.end,
    required this.color,
    this.tag = 'Outros', // NOVO: Valor padrão para a tag
  });

  factory CalendarEventModel.fromFirestore(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return CalendarEventModel(
      id: snapshot.id,
      title: data['title'] ?? 'Sem Título',
      description: data['description'] ?? '',
      start: (data['start'] as Timestamp).toDate(),
      end: (data['end'] as Timestamp).toDate(),
      color: Color(data['color'] ?? Colors.blue.value),
      tag: data['tag'] ?? 'Outros', // NOVO: Lendo a tag do Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'color': color.value,
      'tag': tag, // NOVO: Salvando a tag no Firestore
    };
  }
}