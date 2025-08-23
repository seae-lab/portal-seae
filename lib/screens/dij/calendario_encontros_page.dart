import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
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

  final CalendarController _calendarController = CalendarController();
  DateTime? _selectedDate;
  List<CalendarEventModel> _visibleMonthEvents = [];
  List<CalendarEventModel> _allFilteredEvents = [];

  late final bool canEdit;
  String _selectedTagFilter = 'Todos';
  final List<String> _tagOptions = ['Todos', '1º Ciclo', '2º Ciclo', '3º Ciclo', 'Outros'];

  bool _isMonthView = true;

  @override
  void initState() {
    super.initState();
    canEdit = _authService.currentUserPermissions?.hasRole('admin') ?? false;
    _selectedDate = DateTime.now();
  }

  void _onYearViewChanged(DateRangePickerViewChangedArgs args) {
    if (args.view == DateRangePickerView.month) {
      final DateTime selectedMonth = args.visibleDateRange.startDate!;
      _calendarController.displayDate = selectedMonth;
      setState(() {
        _isMonthView = true;
      });
    }
  }

  void _updateVisibleMonthEvents(List<DateTime> visibleDates) {
    if (visibleDates.isEmpty) return;

    final monthStart = visibleDates.first;
    final monthEnd = visibleDates.last;

    final newVisibleEvents = _allFilteredEvents.where((event) {
      final eventStart = event.start;
      final eventEnd = event.end;
      return (eventStart.isAfter(monthStart) && eventStart.isBefore(monthEnd)) ||
          (eventEnd.isAfter(monthStart) && eventEnd.isBefore(monthEnd)) ||
          (eventStart.isBefore(monthStart) && eventEnd.isAfter(monthEnd)) ||
          eventStart.isAtSameMomentAs(monthStart) ||
          eventEnd.isAtSameMomentAs(monthEnd);
    }).toList();

    newVisibleEvents.sort((a, b) => a.start.compareTo(b.start));

    if (!listEquals(_visibleMonthEvents, newVisibleEvents)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          setState(() {
            _visibleMonthEvents = newVisibleEvents;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Encontros - DIJ'),
        actions: [
          if (_isMonthView) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mês Anterior',
              onPressed: () {
                _calendarController.backward!();
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo Mês',
              onPressed: () {
                _calendarController.forward!();
              },
            ),
          ],
          const SizedBox(width: 20),
          IconButton(
            icon: Icon(_isMonthView
                ? Icons.calendar_view_month_outlined
                : Icons.calendar_month_outlined),
            tooltip: _isMonthView ? 'Ver Ano' : 'Ver Mês',
            onPressed: () {
              setState(() {
                _isMonthView = !_isMonthView;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTagFilter,
                icon: const Icon(Icons.filter_list),
                dropdownColor: Colors.blueGrey[800],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTagFilter = newValue!;
                  });
                },
                items: _tagOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
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
              .toList() ??
              [];

          if (_selectedTagFilter == 'Todos') {
            _allFilteredEvents = allEvents;
          } else {
            _allFilteredEvents = allEvents
                .where((event) => event.tag == _selectedTagFilter)
                .toList();
          }

          if (_isMonthView) {
            return Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        if (pointerSignal.scrollDelta.dy > 0) {
                          _calendarController.forward!();
                        } else if (pointerSignal.scrollDelta.dy < 0) {
                          _calendarController.backward!();
                        }
                      }
                    },
                    child: SfCalendar(
                      controller: _calendarController,
                      dataSource: MeetingDataSource(_allFilteredEvents),
                      view: CalendarView.month,
                      headerHeight: 50,
                      headerStyle: const CalendarHeaderStyle(
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(fontSize: 20)),
                      monthViewSettings: const MonthViewSettings(
                        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                        appointmentDisplayCount: 2,
                      ),
                      appointmentBuilder: _appointmentBuilder,
                      onTap: canEdit ? _onCalendarTapped : null,
                      onViewChanged: (details) => _updateVisibleMonthEvents(details.visibleDates),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Eventos do Mês", style: Theme.of(context).textTheme.titleMedium),
                ),
                const Divider(height: 1),
                Expanded(
                  flex: 2,
                  child: _buildMonthAgenda(),
                )
              ],
            );
          } else {
            return SfDateRangePicker(
              view: DateRangePickerView.year,
              allowViewNavigation: true,
              onViewChanged: _onYearViewChanged,
              monthViewSettings: const DateRangePickerMonthViewSettings(
                firstDayOfWeek: 1,
              ),
            );
          }
        },
      ),
      floatingActionButton: canEdit && _isMonthView
          ? FloatingActionButton(
        onPressed: () => _showAddEventDialog(selectedDate: _selectedDate),
        tooltip: 'Adicionar Evento',
        backgroundColor: const Color.fromRGBO(45, 55, 131, 1),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildMonthAgenda(){
    if (_visibleMonthEvents.isEmpty) {
      return const Center(child: Text("Nenhum evento neste mês."));
    }

    return ListView.builder(
      itemCount: _visibleMonthEvents.length,
      itemBuilder: (context, index) {
        final event = _visibleMonthEvents[index];
        return GestureDetector(
          onTap: () => _showAddEventDialog(event: event), // MUDANÇA: Toque único para editar
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('dd').format(event.start), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(DateFormat('MMM', 'pt_BR').format(event.start), style: const TextStyle(fontSize: 12)),
                ],
              ),
              title: Text(event.title),
              subtitle: Text('${DateFormat('HH:mm').format(event.start)} - ${DateFormat('HH:mm').format(event.end)}'),
              tileColor: event.color.withOpacity(0.1),
            ),
          ),
        );
      },
    );
  }

  void _onCalendarTapped(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final CalendarEventModel event = details.appointments!.first;
      _showAddEventDialog(event: event);
    } else if (details.targetElement == CalendarElement.calendarCell) {
      setState(() {
        _selectedDate = details.date;
      });
    }
  }

  Widget _appointmentBuilder(BuildContext context, CalendarAppointmentDetails details) {
    final event = details.appointments.first as CalendarEventModel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: event.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        event.title,
        style: const TextStyle(color: Colors.white, fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showAddEventDialog(
      {CalendarEventModel? event, DateTime? selectedDate}) {
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

  final List<String> _cicloOptions = ['Todos', '1º Ciclo', '2º Ciclo', '3º Ciclo', 'Outros'];
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

      _startDate = DateTime(now.year, now.month, now.day, 18, 00);
      _endDate = DateTime(now.year, now.month, now.day, 19, 30);

      _selectedColor = _colorOptions.first;
      _selectedTag = _cicloOptions.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime initial = isStart ? _startDate : _endDate;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _startDate.hour, _startDate.minute);
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(hours: 1, minutes: 30));
          }
        } else {
          _endDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _endDate.hour, _endDate.minute);
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final DateTime initial = isStart ? _startDate : _endDate;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day, pickedTime.hour, pickedTime.minute);
        } else {
          _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, pickedTime.hour, pickedTime.minute);
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Adicionar Evento' : 'Editar Evento'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Título', border: OutlineInputBorder()),
                validator: (value) =>
                value!.isEmpty ? 'O título é obrigatório' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedTag,
                decoration: const InputDecoration(
                    labelText: 'Ciclo', border: OutlineInputBorder()),
                items: _cicloOptions.map((String tag) {
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                    labelText: 'Descrição (Opcional)',
                    border: OutlineInputBorder()),
                maxLines: 8,
              ),
              const SizedBox(height: 20),

              _buildDateTimePicker(label: 'Início', date: _startDate, isStart: true),
              _buildDateTimePicker(label: 'Fim', date: _endDate, isStart: false),

              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((color) {
                  return ChoiceChip(
                    label: const SizedBox.shrink(),
                    avatar: CircleAvatar(backgroundColor: color),
                    selected: _selectedColor == color,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedColor = color);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
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

  Widget _buildDateTimePicker({required String label, required DateTime date, required bool isStart}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _selectDate(isStart),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(date)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _selectTime(isStart),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('HH:mm').format(date)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}