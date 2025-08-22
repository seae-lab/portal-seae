import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event_model.dart'; // Importa o modelo correto

class CalendarService {
  final CollectionReference _eventsCollection =
  FirebaseFirestore.instance.collection('dij_calendar_events');

  // O serviço simplesmente retorna o fluxo de dados brutos do Firestore.
  Stream<QuerySnapshot> getCalendarEvents() {
    return _eventsCollection.snapshots();
  }

  Future<void> addEvent(CalendarEventModel event) {
    return _eventsCollection.add(event.toFirestore());
  }

  Future<void> updateEvent(CalendarEventModel event) {
    return _eventsCollection.doc(event.id).update(event.toFirestore());
  }

  Future<void> deleteEvent(String eventId) {
    return _eventsCollection.doc(eventId).delete();
  }
}