// lib/screens/home/pages/secretaria/dashboard_page.dart

import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/services/cadastro_service.dart';
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
    Colors.cyan.shade400,
    Colors.amber.shade400,
    Colors.pink.shade400,
    Colors.green.shade400,
    Colors.purple.shade400,
    Colors.orange.shade400,
    Colors.teal.shade400,
    Colors.red.shade400,
  ];

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadInitialDashboardData();
  }

  Future<DashboardData> _loadInitialDashboardData() async {
    final results = await Future.wait([
      _cadastroService.getMembros().first,
      _cadastroService.getSituacoes(),
      _cadastroService.getDepartamentos(),
    ]);

    final rawDepartamentos = results[2] as List<String>;
    final processedDepartamentos = rawDepartamentos.map((d) => d.split('/').first).toSet().toList();
    _membros = results[0] as List<Membro>;

    final Set<String> years = {};
    for (var membro in _membros) {
      years.addAll(membro.contribuicao.keys);
    }
    _availableYears = years.toList()..sort();

    if (_selectedYear == null && _availableYears.isNotEmpty) {
      _selectedYear = _availableYears.last;
    }

    // Chamada inicial para popular o mapa com o ano mais recente
    await _updateMarkersForYear(_selectedYear);

    return DashboardData(
      membros: _membros,
      situacoes: results[1] as Map<String, String>,
      departamentos: processedDepartamentos,
    );
  }

  Future<void> _updateMarkersForYear(String? year) async {
    _contribuicaoPorBairro.clear();

    if (year == null) {
      setState(() {
        _markers = [];
      });
      return;
    }

    for (var membro in _membros) {
      int annualContributions = 0;

      if (membro.contribuicao.containsKey(year)) {
        final data = membro.contribuicao[year] as Map<String, dynamic>;

        if (data['quitado'] == true) {
          annualContributions = 1;
        } else {
          final meses = data['meses'] as Map<String, dynamic>?;
          if (meses != null && meses.values.any((isPaid) => isPaid == true)) {
            annualContributions = 1;
          }
        }
      }

      if (annualContributions > 0) {
        final bairro = membro.dadosPessoais.bairro.trim().toLowerCase();
        if (bairro.isNotEmpty) {
          _contribuicaoPorBairro.update(bairro, (value) => value + annualContributions,
              ifAbsent: () => annualContributions);
        }
      }
    }

    final List<Future<void>> futures = [];
    final List<Marker> markersList = [];

    for (final entry in _contribuicaoPorBairro.entries) {
      final bairro = entry.key;
      final contribuicoes = entry.value;

      futures.add(() async {
        final point = await _cadastroService.getCoordinatesFromBairro(bairro) ?? LatLng(-15.7934, -47.8825);

        markersList.add(
          Marker(
            width: 120,
            height: 80,
            point: point,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$bairro: $contribuicoes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                Icon(Icons.location_on, color: Colors.blue.shade700, size: 30),
              ],
            ),
          ),
        );
      }());
    }

    await Future.wait(futures);

    setState(() {
      _markers = markersList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard da Secretaria'),
        centerTitle: false,
      ),
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.membros.isEmpty) {
            return const Center(child: Text('Nenhum dado encontrado.'));
          }

          final data = snapshot.data!;
          final totalMembros = data.membros.length;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardDataFuture = _loadInitialDashboardData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Visão Geral - Total de $totalMembros membros',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 24),
                _buildMapaContribuicoes(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildSituacaoChart(data.membros, data.situacoes)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDepartamentoChart(data.membros, data.departamentos)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildContribuicaoChart(data.membros),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildSituacaoChart(data.membros, data.situacoes),
                        const SizedBox(height: 16),
                        _buildDepartamentoChart(data.membros, data.departamentos),
                        const SizedBox(height: 16),
                        _buildContribuicaoChart(data.membros),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapaContribuicoes() {
    final LatLng center = LatLng(-15.7934, -47.8825);

    return _buildChartCard(
      title: 'Distribuição de Contribuições',
      chart: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: _selectedYear,
                hint: const Text('Selecione o ano'),
                underline: const SizedBox(),
                items: _availableYears.map((String year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedYear = newValue;
                  });
                  _updateMarkersForYear(newValue);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 4,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 24),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildSituacaoChart(
      List<Membro> membros, Map<String, String> situacoes) {
    final Map<String, int> situacaoCount = {};
    for (var membro in membros) {
      final situacaoId = membro.situacaoSEAE.toString();
      final situacaoNome = situacoes[situacaoId] ?? 'Não definida';
      situacaoCount[situacaoNome] = (situacaoCount[situacaoNome] ?? 0) + 1;
    }

    return _buildChartCard(
      title: 'Membros por Situação',
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (situacaoCount.values
              .fold(0.0, (max, v) => v > max ? v.toDouble() : max) *
              1.2)
              .ceilToDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String weekDay = situacaoCount.keys.elementAt(group.x.toInt());
                final value = rod.toY.toInt();
                return BarTooltipItem(
                  '$weekDay\n',
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  children: <TextSpan>[
                    TextSpan(
                      text: value.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: situacaoCount.entries.map((entry) {
            final index = situacaoCount.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  width: 16,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade800],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < situacaoCount.keys.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      angle: -0.5,
                      child: Text(
                        situacaoCount.keys.elementAt(index),
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (situacaoCount.values
                    .fold(0.0, (max, v) => v > max ? v.toDouble() : max) /
                    5)
                    .ceilToDouble(),
                getTitlesWidget: (value, meta) =>
                    Text('${value.toInt()}', style: const TextStyle(fontSize: 11)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (situacaoCount.values
                .fold(0.0, (max, v) => v > max ? v.toDouble() : max) /
                5)
                .ceilToDouble(),
            getDrawingHorizontalLine: (value) =>
            const FlLine(color: Colors.black12, strokeWidth: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartamentoChart(
      List<Membro> membros, List<String> departamentos) {
    final Map<String, int> deptoCount = {for (var d in departamentos) d: 0};

    for (var membro in membros) {
      final memberMainDepts = membro.atividades.map((a) => a.split('/').first).toSet();

      for (var mainDept in memberMainDepts) {
        if (deptoCount.containsKey(mainDept)) {
          deptoCount[mainDept] = deptoCount[mainDept]! + 1;
        }
      }
    }

    final totalMemberAssignments =
    deptoCount.values.fold(0, (sum, count) => sum + count);

    deptoCount.removeWhere((key, value) => value == 0);

    final List<PieChartSectionData> sections = deptoCount.entries.map((entry) {
      final index = deptoCount.keys.toList().indexOf(entry.key);
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 120.0 : 110.0;
      final percentage = totalMemberAssignments > 0
          ? (entry.value / totalMemberAssignments * 100).toStringAsFixed(1)
          : "0.0";

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '$percentage%',
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
        ),
        radius: radius,
        color: _colorPalette[index % _colorPalette.length],
        borderSide: isTouched
            ? BorderSide(
            color: _colorPalette[index % _colorPalette.length].withAlpha(204),
            width: 6)
            : const BorderSide(color: Color.fromRGBO(255, 255, 255, 0)),
        badgeWidget: _buildChartBadge(
            entry.key, _colorPalette[index % _colorPalette.length]),
        badgePositionPercentageOffset: .98,
      );
    }).toList();

    return _buildChartCard(
      title: 'Membros por Departamento',
      chart: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  touchedIndex = -1;
                  return;
                }
                touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sections: sections,
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 45,
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
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildContribuicaoChart(List<Membro> membros) {
    final Map<String, int> contribuicaoCount = {};
    for (var membro in membros) {
      membro.contribuicao.forEach((year, data) {
        if (data is Map) {
          if (data['quitado'] == true) {
            contribuicaoCount[year] = (contribuicaoCount[year] ?? 0) + 1;
            return;
          }
          final meses = data['meses'] as Map<String, dynamic>?;
          if (meses != null && meses.values.any((isPaid) => isPaid == true)) {
            contribuicaoCount[year] = (contribuicaoCount[year] ?? 0) + 1;
          }
        }
      });
    }

    final sortedKeys = contribuicaoCount.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return _buildChartCard(
          title: 'Total de Membros Contribuintes por Ano',
          chart: const Center(child: Text("Nenhum dado de contribuição.")));
    }

    final List<FlSpot> spots = sortedKeys.map((year) {
      return FlSpot(double.parse(year), contribuicaoCount[year]!.toDouble());
    }).toList();

    return _buildChartCard(
      title: 'Total de Membros Contribuintes por Ano',
      chart: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) =>
              const Color.fromRGBO(96, 125, 139, 0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    'Ano: ${touchedSpot.x.toInt()}\nMembros: ${touchedSpot.y.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) =>
              const FlLine(color: Colors.black12, strokeWidth: 1)),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: sortedKeys.length > 5
                    ? (sortedKeys.length / 4).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(value.toInt().toString(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (contribuicaoCount.values
                    .fold(0.0, (max, v) => v > max ? v.toDouble() : max) /
                    5)
                    .ceilToDouble(),
                getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.black12)),
          minX: double.parse(sortedKeys.first),
          maxX: double.parse(sortedKeys.last),
          minY: 0,
          maxY: (contribuicaoCount.values
              .fold(0.0, (max, v) => v > max ? v.toDouble() : max) *
              1.2)
              .ceilToDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(colors: [
                Colors.green.shade300,
                Colors.green.shade800
              ]),
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                        radius: 6,
                        color: Colors.green.shade800,
                        strokeWidth: 2,
                        strokeColor: Colors.white),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade300.withAlpha(77),
                    Colors.green.shade800.withAlpha(0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardData {
  final List<Membro> membros;
  final Map<String, String> situacoes;
  final List<String> departamentos;

  DashboardData({
    required this.membros,
    required this.situacoes,
    required this.departamentos,
  });
}