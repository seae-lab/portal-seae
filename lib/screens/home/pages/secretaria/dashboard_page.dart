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
    // Busca todos os dados em paralelo
    final results = await Future.wait([
      _cadastroService.getMembros().first, // Pega o primeiro evento do stream (a lista atual)
      _cadastroService.getSituacoes(),
      _cadastroService.getDepartamentos(),
    ]);

    return DashboardData(
      membros: results[0] as List<Membro>,
      situacoes: results[1] as Map<String, String>,
      departamentos: (results[2] as List<String>).toSet().toList(), // Garante departamentos únicos
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
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                // MODIFICADO: Layout responsivo para os gráficos
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Para telas largas, mostra os 2 primeiros gráficos lado a lado
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
                    // Para telas estreitas, mostra um gráfico por linha
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  // Gráfico de Barras para Situação
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
          maxY: situacaoCount.values.fold(0, (max, v) => v > max ? v : max).toDouble() + 2,
          barGroups: situacaoCount.entries.map((entry) {
            final index = situacaoCount.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: Colors.orange,
                  width: 16,
                  borderRadius: BorderRadius.zero,
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
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(situacaoCount.keys.elementAt(index), style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }

  // Gráfico de Pizza para Departamento
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

    final List<PieChartSectionData> sections = deptoCount.entries.map((entry) {
      final index = deptoCount.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.value}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 100,
        color: Colors.primaries[index % Colors.primaries.length],
      );
    }).toList();

    return _buildChartCard(
      title: 'Membros por Departamento',
      chart: Row(
        children: [
          Expanded( // Gráfico de pizza na esquerda
            child: PieChart(
              PieChartData(
                sections: sections,
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          Column( // Legenda na direita
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: deptoCount.keys.map((name) {
              final index = deptoCount.keys.toList().indexOf(name);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(children: [
                  Container(width: 8, height: 8, color: Colors.primaries[index % Colors.primaries.length]),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(fontSize: 12)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Gráfico de Linha para Contribuição
  Widget _buildContribuicaoChart(List<Membro> membros) {
    final Map<String, int> contribuicaoCount = {};
    for (var membro in membros) {
      for (var entry in membro.contribuicao.entries) {
        if (entry.value == true) {
          contribuicaoCount[entry.key] = (contribuicaoCount[entry.key] ?? 0) + 1;
        }
      }
    }

    final sortedKeys = contribuicaoCount.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return _buildChartCard(title: 'Contribuições Pagas por Ano', chart: const Center(child: Text("Nenhum dado de contribuição.")));
    }

    final List<FlSpot> spots = sortedKeys.map((year) {
      return FlSpot(double.parse(year), contribuicaoCount[year]!.toDouble());
    }).toList();

    return _buildChartCard(
      title: 'Contribuições Pagas por Ano',
      chart: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: sortedKeys.length > 10 ? (sortedKeys.length / 5).roundToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: double.parse(sortedKeys.first),
          maxX: double.parse(sortedKeys.last),
          minY: 0,
          maxY: contribuicaoCount.values.fold(0, (max, v) => v > max ? v : max).toDouble() + 2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Classe auxiliar para agrupar os dados do dashboard
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
