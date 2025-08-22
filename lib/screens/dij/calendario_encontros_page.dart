import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:projetos/services/auth_service.dart';
import '../../models/calendar_event_model.dart';
import '../../services/calendar_service.dart';

class CalendarioEncontrosPage extends StatefulWidget {
  const CalendarioEncontrosPage({super.key});

  @override
  State<CalendarioEncontrosPage> createState() =>
      _CalendarioEncontrosPageState();
}

class _CalendarioEncontrosPageState extends State<CalendarioEncontrosPage> {
  final CalendarService _calendarService = Modular.get<CalendarService>();
  final AuthService _authService = Modular.get<AuthService>();

  late final bool canEdit;

  String _selectedTagFilter = 'Todos';
  final List<String> _tagOptions = ['Todos', '1º Ciclo', '2º Ciclo', '3º Ciclo', 'Outros'];

  // CORREÇÃO: A visão é controlada por uma variável de estado simples.
  CalendarView _currentView = CalendarView.month;

  @override
  void initState() {
    super.initState();
    canEdit = _authService.currentUserPermissions?.hasRole('admin') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO: Define a cor do ícone e do texto do dropdown baseada no tema da AppBar
    final appBarIconColor = Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white;
    final appBarTextColor = Theme.of(context).appBarTheme.titleTextStyle?.color ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Encontros - DIJ'),
        actions: [
          IconButton(
            icon: Icon(_currentView == CalendarView.month
                ? Icons.view_agenda_outlined
                : Icons.calendar_month_outlined),
            tooltip: _currentView == CalendarView.month
                ? 'Ver Agenda Anual'
                : 'Ver Mês',
            onPressed: () {
              setState(() {
                _currentView = _currentView == CalendarView.month
                    ? CalendarView.schedule
                    : CalendarView.month;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTagFilter,
                icon: Icon(Icons.filter_list, color: appBarIconColor),
                dropdownColor: Colors.blueGrey[800],
                // CORREÇÃO: O estilo do texto agora se adapta ao tema da AppBar
                style: TextStyle(color: appBarTextColor, fontSize: 16),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTagFilter = newValue!;
                  });
                },
                items: _tagOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    // O texto dentro do menu suspenso será sempre branco para contrastar
                    child: Text(value, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _calendarService.getCalendarEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          var allEvents = snapshot.data?.docs
              .map((doc) => CalendarEventModel.fromFirestore(doc))
              .toList() ?? [];

          List<CalendarEventModel> filteredEvents;
          if (_selectedTagFilter == 'Todos') {
            filteredEvents = allEvents;
          } else {
            filteredEvents = allEvents.where((event) => event.tag == _selectedTagFilter).toList();
          }

          return SfCalendar(
            view: _currentView,
            dataSource: MeetingDataSource(filteredEvents),
            // CORREÇÃO: Força a visão de agenda a iniciar em 1º de Janeiro do ano atual
            initialDisplayDate: _currentView == CalendarView.schedule
                ? DateTime(DateTime.now().year, 1, 1)
                : DateTime.now(),
            headerHeight: 50,
            headerStyle: const CalendarHeaderStyle(
                textAlign: TextAlign.center,
                textStyle: TextStyle(fontSize: 20)
            ),
            scheduleViewSettings: const ScheduleViewSettings(
              appointmentItemHeight: 70,
              monthHeaderSettings: MonthHeaderSettings(
                height: 60,
                textAlign: TextAlign.left,
                backgroundColor: Color(0xFF3F51B5), // Cor índigo, mais padrão
                monthTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            monthViewSettings: const MonthViewSettings(
              showAgenda: true,
              agendaItemHeight: 50,
            ),
            onTap: canEdit ? _onCalendarTapped : null,
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
        onPressed: () => _showAddEventDialog(selectedDate: DateTime.now()),
        tooltip: 'Adicionar Evento',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  void _onCalendarTapped(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final CalendarEventModel event = details.appointments!.first;
      _showAddEventDialog(event: event);
    } else if (details.targetElement == CalendarElement.calendarCell) {
      final DateTime selectedDate = details.date!;
      _showAddEventDialog(selectedDate: selectedDate);
    }
  }

  void _showAddEventDialog({CalendarEventModel? event, DateTime? selectedDate}) {
    showDialog(
      context: context,
      builder: (context) => EventDialog(
        event: event,
        selectedDate: selectedDate,
        onSave: (newEvent) async {
          if (newEvent.id != null) {
            await _calendarService.updateEvent(newEvent);
          } else {
            await _calendarService.addEvent(newEvent);
          }
          if (mounted) Navigator.of(context).pop();
        },
        onDelete: event != null
            ? () async {
          await _calendarService.deleteEvent(event.id!);
          if (mounted) Navigator.of(context).pop();
        }
            : null,
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<CalendarEventModel> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return (appointments![index] as CalendarEventModel).start;
  }

  @override
  DateTime getEndTime(int index) {
    return (appointments![index] as CalendarEventModel).end;
  }

  @override
  String getSubject(int index) {
    return (appointments![index] as CalendarEventModel).title;
  }

  @override
  Color getColor(int index) {
    return (appointments![index] as CalendarEventModel).color;
  }

  @override
  Object? getRecurrenceId(int index) {
    return (appointments![index] as CalendarEventModel).tag;
  }
}

class EventDialog extends StatefulWidget {
  final CalendarEventModel? event;
  final DateTime? selectedDate;
  final Function(CalendarEventModel) onSave;
  final VoidCallback? onDelete;

  const EventDialog({
    super.key,
    this.event,
    this.selectedDate,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  late Color _selectedColor;
  late String _selectedTag;
  final List<String> _tagOptions = ['1º Ciclo', '2º Ciclo', '3º Ciclo', 'Outros'];
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal
  ];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _descriptionController =
          TextEditingController(text: widget.event!.description);
      _startDate = widget.event!.start;
      _endDate = widget.event!.end;
      _selectedColor = widget.event!.color;
      _selectedTag = widget.event!.tag;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      final now = widget.selectedDate ?? DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day, 19, 0);
      _endDate = _startDate.add(const Duration(hours: 1));
      _selectedColor = _colorOptions.first;
      _selectedTag = _tagOptions.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
    );
    if (time == null) return;

    setState(() {
      final newDateTime =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startDate = newDateTime;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = newDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Adicionar Evento' : 'Editar Evento'),
      // CORREÇÃO: O SizedBox agora usa uma largura máxima fixa, ideal para diálogos.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                    validator: (value) =>
                    value!.isEmpty ? 'O título é obrigatório' : null,
                  ),
                  const SizedBox(height: 20), // Mais espaço vertical
                  DropdownButtonFormField<String>(
                    value: _selectedTag,
                    decoration: const InputDecoration(labelText: 'Tag', border: OutlineInputBorder()),
                    items: _tagOptions.map((String tag) {
                      return DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedTag = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 20), // Mais espaço vertical
                  TextFormField(
                    controller: _descriptionController,
                    decoration:
                    const InputDecoration(labelText: 'Descrição (Opcional)', border: OutlineInputBorder()),
                    maxLines: 6, // Um pouco mais de altura
                  ),
                  const SizedBox(height: 20), // Mais espaço vertical
                  ListTile(
                    title: const Text('Início'),
                    subtitle:
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(_startDate)),
                    onTap: () => _selectDateTime(context, true),
                    trailing: const Icon(Icons.calendar_today),
                  ),
                  ListTile(
                    title: const Text('Fim'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_endDate)),
                    onTap: () => _selectDateTime(context, false),
                    trailing: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _colorOptions.map((color) {
                      return ChoiceChip(
                        label: const SizedBox.shrink(),
                        avatar: CircleAvatar(backgroundColor: color),
                        selected: _selectedColor == color,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedColor = color);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newEvent = CalendarEventModel(
                id: widget.event?.id,
                title: _titleController.text,
                description: _descriptionController.text,
                start: _startDate,
                end: _endDate,
                color: _selectedColor,
                tag: _selectedTag,
              );
              widget.onSave(newEvent);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}