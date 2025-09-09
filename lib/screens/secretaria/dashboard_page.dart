import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:projetos/services/secretaria_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/membro.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  late Future<DashboardData> _dashboardDataFuture;
  int touchedIndex = -1;
  final Map<String, int> _contribuicaoPorBairro = {};

  List<Marker> _markers = [];
  List<Membro> _membros = [];

  String? _selectedYear;
  List<String> _availableYears = [];

  final List<Color> _colorPalette = [
    Colors.cyan.shade400, Colors.amber.shade400, Colors.pink.shade400,
    Colors.green.shade400, Colors.purple.shade400, Colors.orange.shade400,
    Colors.teal.shade400, Colors.red.shade400,
  ];

  final List<Color> _generationBarColors = [
    Colors.red.shade700, Colors.blueGrey, Colors.deepOrange, Colors.indigo,
    Colors.green, Colors.purple, Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadInitialDashboardData();
  }

  Future<Map<String, int>> _getAgeDistribution() async {
    final List<int> birthYears = [];

    final membrosAtivos = _membros.where((m) => m.situacaoSEAE != 5 && m.situacaoSEAE != 6);

    for (var membro in membrosAtivos) {
      final dateString = membro.dadosPessoais.dataNascimento;
      if (dateString.isNotEmpty) {
        try {
          final dateParts = dateString.split('/');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[2]);
            if (year > 1900) birthYears.add(year);
          }
        } catch (e) {/* Ignora */}
      }
    }

    final jovensSnapshot = await _cadastroService.membrosCollection.firestore.collection('base_dij/base_jovens/jovens').get();
    for (var doc in jovensSnapshot.docs) {
      final data = doc.data();
      final dateString = data['dataNascimento'] as String?;
      if (dateString != null && dateString.isNotEmpty) {
        try {
          final dateParts = dateString.split('/');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[2]);
            if (year > 1900) birthYears.add(year);
          }
        } catch (e) {/* Ignora */}
      }
    }

    final Map<String, int> generationBrackets = {
      'G. Grandiosa (1901-1927)': 0, 'G. Silenciosa (1928-1945)': 0,
      'Baby Boomers (1946-1964)': 0, 'Geração X (1965-1980)': 0,
      'Millennials (1981-1996)': 0, 'Geração Z (1997-2012)': 0,
      'Geração Alpha (2013+)': 0,
    };

    for (var year in birthYears) {
      if (year <= 1927) generationBrackets['G. Grandiosa (1901-1927)'] = (generationBrackets['G. Grandiosa (1901-1927)'] ?? 0) + 1;
      else if (year <= 1945) generationBrackets['G. Silenciosa (1928-1945)'] = (generationBrackets['G. Silenciosa (1928-1945)'] ?? 0) + 1;
      else if (year <= 1964) generationBrackets['Baby Boomers (1946-1964)'] = (generationBrackets['Baby Boomers (1946-1964)'] ?? 0) + 1;
      else if (year <= 1980) generationBrackets['Geração X (1965-1980)'] = (generationBrackets['Geração X (1965-1980)'] ?? 0) + 1;
      else if (year <= 1996) generationBrackets['Millennials (1981-1996)'] = (generationBrackets['Millennials (1981-1996)'] ?? 0) + 1;
      else if (year <= 2012) generationBrackets['Geração Z (1997-2012)'] = (generationBrackets['Geração Z (1997-2012)'] ?? 0) + 1;
      else if (year >= 2013) generationBrackets['Geração Alpha (2013+)'] = (generationBrackets['Geração Alpha (2013+)'] ?? 0) + 1;
    }

    generationBrackets.removeWhere((key, value) => value == 0);
    return generationBrackets;
  }

  Future<DashboardData> _loadInitialDashboardData() async {
    final results = await Future.wait([
      _cadastroService.getMembros().first,
      _cadastroService.getSituacoes(),
      _cadastroService.getDepartamentos(),
    ]);

    _membros = results[0] as List<Membro>;
    final ageDistribution = await _getAgeDistribution();

    final rawDepartamentos = (results[2] as List<String>).map((d) => d.split('/').first).toSet().toList();

    final Set<String> years = {};
    for (var membro in _membros) {
      years.addAll(membro.contribuicao.keys);
    }
    _availableYears = years.toList()..sort((a, b) => b.compareTo(a));

    if (_selectedYear == null && _availableYears.isNotEmpty) {
      _selectedYear = _availableYears.first;
    }
    await _updateMarkersForYear(_selectedYear);

    return DashboardData(
      membros: _membros,
      situacoes: results[1] as Map<String, String>,
      departamentos: rawDepartamentos,
      ageDistribution: ageDistribution,
    );
  }

  Future<void> _updateMarkersForYear(String? year) async {
    _contribuicaoPorBairro.clear();
    if (year == null || _membros.isEmpty) {
      if (mounted) setState(() => _markers = []);
      return;
    }
    for (var membro in _membros) {
      if (membro.contribuicao.containsKey(year)) {
        final data = membro.contribuicao[year];
        if (data is Map && (data['quitado'] == true || (data['meses'] as Map?)?.values.any((p) => p == true) == true)) {
          final bairro = membro.dadosPessoais.bairro.trim().toLowerCase();
          if (bairro.isNotEmpty) {
            _contribuicaoPorBairro.update(bairro, (value) => value + 1, ifAbsent: () => 1);
          }
        }
      }
    }
    final List<Marker> markersList = [];
    for (final entry in _contribuicaoPorBairro.entries) {
      final point = await _cadastroService.getCoordinatesFromBairro(entry.key);
      if (point != null) {
        markersList.add(Marker(point: point, width: 120, height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                child: Text('${entry.key}: ${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 30),
            ],
          ),
        ));
      }
    }
    if (mounted) setState(() => _markers = markersList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard da Secretaria'), centerTitle: false),
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.membros.isEmpty) return const Center(child: Text('Nenhum membro encontrado.'));

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _dashboardDataFuture = _loadInitialDashboardData()),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text('Visão Geral - Total de ${data.membros.length} membros', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
                const SizedBox(height: 24),
                _buildMapaContribuicoes(),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 900;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildSituacaoChart(data.membros, data.situacoes)),
                      if (isWide) const SizedBox(width: 16),
                      if (!isWide) const SizedBox(height: 16),
                      Expanded(child: _buildDepartamentoChart(data.membros, data.departamentos)),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                _buildContribuicaoChart(data.membros),
                const SizedBox(height: 24),
                _buildAgeDistributionChart(data.ageDistribution),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgeDistributionChart(Map<String, int> ageData) {
    if (ageData.isEmpty) {
      return const SizedBox.shrink();
    }
    final totalPessoas = ageData.values.reduce((a, b) => a + b);
    final maxValue = ageData.values.reduce((a, b) => a > b ? a : b);
    final formatter = NumberFormat.decimalPattern("pt_BR");
    final currentYear = DateTime.now().year;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Faixas Etárias da População', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('Estimativa ($currentYear) - Total: ${formatter.format(totalPessoas)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ...ageData.entries.map((entry) {
              final index = ageData.keys.toList().indexOf(entry.key);
              return _buildChartRow(
                label: entry.key,
                value: entry.value,
                maxValue: maxValue,
                color: _generationBarColors[index % _generationBarColors.length],
                formatter: formatter,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChartRow({required String label, required int value, required int maxValue, required Color color, required NumberFormat formatter}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 16),
              Text("= ${formatter.format(value)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = maxValue > 0 ? constraints.maxWidth * (value / maxValue) : 0.0;
              return Container(
                width: constraints.maxWidth, height: 22,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: barWidth.toDouble(), height: 22,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 24),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildMapaContribuicoes() {
    return _buildChartCard(
      title: 'Distribuição de Contribuições',
      chart: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: LatLng(-15.7934, -47.8825), initialZoom: 11.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'br.org.seae.projetos'),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_availableYears.isNotEmpty)
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]),
                child: DropdownButton<String>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  items: _availableYears.map((year) => DropdownMenuItem<String>(value: year, child: Text(year))).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _selectedYear = newValue);
                      _updateMarkersForYear(newValue);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSituacaoChart(List<Membro> membros, Map<String, String> situacoes) {
    final Map<String, int> dataMap = {};
    for (var membro in membros) {
      final situacaoNome = situacoes[membro.situacaoSEAE.toString()] ?? 'Não definida';
      dataMap.update(situacaoNome, (value) => value + 1, ifAbsent: () => 1);
    }
    if (dataMap.isEmpty) return _buildChartCard(title: 'Membros por Situação', chart: const Center(child: Text("Nenhum dado para exibir.")));

    final double maxVal = dataMap.values.fold(0, (max, v) => v > max ? v : max).toDouble();
    final double interval = maxVal > 0 ? (maxVal / 5).ceilToDouble() : 1;

    return _buildChartCard(
      title: 'Membros por Situação',
      chart: BarChart(
        BarChartData(
          maxY: maxVal > 0 ? maxVal * 1.2 : 5,
          barGroups: dataMap.entries.map((entry) {
            final index = dataMap.keys.toList().indexOf(entry.key);
            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(toY: entry.value.toDouble(), width: 16, borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade800], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                getTitlesWidget: (value, meta) => SideTitleWidget(axisSide: meta.axisSide, angle: -0.5, child: Text(dataMap.keys.elementAt(value.toInt()), style: const TextStyle(fontSize: 10))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: interval,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval),
        ),
      ),
    );
  }

  Widget _buildDepartamentoChart(List<Membro> membros, List<String> departamentos) {
    final Map<String, int> dataMap = {};
    for (var membro in membros) {
      for (var depto in membro.atividades.map((a) => a.split('/').first)) {
        dataMap.update(depto, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    if (dataMap.isEmpty) return _buildChartCard(title: 'Membros por Departamento', chart: const Center(child: Text("Nenhum dado para exibir.")));

    final totalMemberAssignments = dataMap.values.fold(0, (sum, count) => sum + count);

    return _buildChartCard(
      title: 'Membros por Departamento',
      chart: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(touchCallback: (event, pieTouchResponse) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1;
              });
            });
          }),
          sections: dataMap.entries.map((entry) {
            final index = dataMap.keys.toList().indexOf(entry.key);
            final isTouched = index == touchedIndex;
            final percentage = totalMemberAssignments > 0 ? (entry.value / totalMemberAssignments * 100) : 0.0;
            return PieChartSectionData(
              color: _colorPalette[index % _colorPalette.length],
              value: entry.value.toDouble(),
              title: '${percentage.toStringAsFixed(1)}%',
              radius: isTouched ? 120.0 : 110.0,
              titleStyle: TextStyle(fontSize: isTouched ? 18.0 : 14.0, fontWeight: FontWeight.bold, color: Colors.white, shadows: const [Shadow(color: Colors.black38, blurRadius: 2)]),
              badgeWidget: _buildChartBadge(entry.key, _colorPalette[index % _colorPalette.length]),
              badgePositionPercentageOffset: .98,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContribuicaoChart(List<Membro> membros) {
    final Map<String, int> dataMap = {};
    for (var membro in membros) {
      membro.contribuicao.forEach((year, data) {
        if (data is Map && (data['quitado'] == true || (data['meses'] as Map?)?.values.any((p) => p == true) == true)) {
          dataMap.update(year, (value) => value + 1, ifAbsent: () => 1);
        }
      });
    }

    final sortedYears = dataMap.keys.toList()..sort();
    if (sortedYears.isEmpty) return _buildChartCard(title: 'Total de Contribuintes por Ano', chart: const Center(child: Text("Nenhum dado para exibir.")));

    final double maxVal = dataMap.values.fold(0, (max, v) => v > max ? v : max).toDouble();
    final double interval = maxVal > 0 ? (maxVal / 5).ceilToDouble() : 1;

    return _buildChartCard(
      title: 'Total de Contribuintes por Ano',
      chart: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal > 0 ? maxVal * 1.2 : 5,
          lineBarsData: [
            LineChartBarData(
              spots: sortedYears.map((year) => FlSpot(double.parse(year), dataMap[year]!.toDouble())).toList(),
              isCurved: true,
              gradient: LinearGradient(colors: [Colors.green.shade300, Colors.green.shade800]),
              barWidth: 5,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: sortedYears.length > 5 ? (sortedYears.length / 4).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: interval,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: interval),
        ),
      ),
    );
  }

  Widget _buildChartBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class DashboardData {
  final List<Membro> membros;
  final Map<String, String> situacoes;
  final List<String> departamentos;
  final Map<String, int> ageDistribution;

  DashboardData({
    required this.membros,
    required this.situacoes,
    required this.departamentos,
    required this.ageDistribution,
  });
}

