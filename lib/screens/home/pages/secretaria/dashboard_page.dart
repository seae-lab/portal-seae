import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:projetos/screens/models/membro.dart';
import 'package:projetos/services/cadastro_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CadastroService _cadastroService = Modular.get<CadastroService>();
  late Future<DashboardData> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadDashboardData();
  }

  Future<DashboardData> _loadDashboardData() async {
    final results = await Future.wait([
      _cadastroService.getMembros().first,
      _cadastroService.getSituacoes(),
      _cadastroService.getDepartamentos(),
    ]);

    return DashboardData(
      membros: results[0] as List<Membro>,
      situacoes: results[1] as Map<String, String>,
      departamentos: (results[2] as List<String>).toSet().toList(),
    );
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
                _dashboardDataFuture = _loadDashboardData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Visão Geral - Total de ${totalMembros} membros',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
                ),
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

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
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

  Widget _buildSituacaoChart(List<Membro> membros, Map<String, String> situacoes) {
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
          maxY: situacaoCount.values.fold(0, (max, v) => v > max ? v : max).toDouble() * 1.2,
          barGroups: situacaoCount.entries.map((entry) {
            final index = situacaoCount.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(situacaoCount.keys.elementAt(index), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 32,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: (situacaoCount.values.fold(0, (max, v) => v > max ? v : max) / 5).ceilToDouble())),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (situacaoCount.values.fold(0, (max, v) => v > max ? v : max) / 5).ceilToDouble(), getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1)),
        ),
      ),
    );
  }

  Widget _buildDepartamentoChart(List<Membro> membros, List<String> departamentos) {
    final Map<String, int> deptoCount = { for (var d in departamentos) d : 0 };
    for (var membro in membros) {
      for (var atividade in membro.atividades) {
        if (deptoCount.containsKey(atividade)) {
          deptoCount[atividade] = deptoCount[atividade]! + 1;
        }
      }
    }
    deptoCount.removeWhere((key, value) => value == 0);
    final List<Color> colors = [Colors.cyan, Colors.amber, Colors.pink, Colors.green, Colors.purple, Colors.orange];

    final List<PieChartSectionData> sections = deptoCount.entries.map((entry) {
      final index = deptoCount.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
        radius: 110,
        color: colors[index % colors.length],
      );
    }).toList();

    return _buildChartCard(
      title: 'Membros por Departamento',
      chart: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: sections,
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 45,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: deptoCount.keys.map((name) {
                final index = deptoCount.keys.toList().indexOf(name);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(children: [
                    Container(width: 12, height: 12, color: colors[index % colors.length]),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontSize: 13)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContribuicaoChart(List<Membro> membros) {
    final Map<String, int> contribuicaoCount = {};
    for (var membro in membros) {
      membro.contribuicao.forEach((year, data) {
        if (data is Map) {
          final meses = data['meses'] as Map<String, dynamic>?;
          if (meses != null) {
            final paidMonthsInYear = meses.values.where((isPaid) => isPaid == true).length;
            if (paidMonthsInYear > 0) {
              contribuicaoCount[year] = (contribuicaoCount[year] ?? 0) + paidMonthsInYear;
            }
          }
        }
      });
    }

    final sortedKeys = contribuicaoCount.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return _buildChartCard(title: 'Meses Pagos por Ano', chart: const Center(child: Text("Nenhum dado de contribuição.")));
    }

    final List<FlSpot> spots = sortedKeys.map((year) {
      return FlSpot(double.parse(year), contribuicaoCount[year]!.toDouble());
    }).toList();

    return _buildChartCard(
      title: 'Total de Meses Pagos por Ano',
      chart: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1)),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: sortedKeys.length > 5 ? (sortedKeys.length / 4).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: (contribuicaoCount.values.fold(0, (max, v) => v > max ? v : max) / 5).ceilToDouble())),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
          minX: double.parse(sortedKeys.first),
          maxX: double.parse(sortedKeys.last),
          minY: 0,
          maxY: contribuicaoCount.values.fold(0, (max, v) => v > max ? v : max).toDouble() * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(colors: [Colors.green.shade300, Colors.green.shade700]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 5, color: Colors.green.shade800, strokeWidth: 1, strokeColor: Colors.white)),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [Colors.green.shade300.withOpacity(0.3), Colors.green.shade700.withOpacity(0.0)],
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
