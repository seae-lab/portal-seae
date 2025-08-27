// Conteúdo atualizado de ferrazt/pag-seae/pag-seae-f1ecfa12a567d6280aa4dbc6787d965af79b4a34/lib/screens/dij/dij_page.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:projetos/models/chamada_dij_model.dart';
import 'package:projetos/services/dij_service.dart';

class DijPage extends StatefulWidget {
  const DijPage({super.key});

  @override
  State<DijPage> createState() => _DijPageState();
}

class _DijPageState extends State<DijPage> {
  final DijService _dijService = Modular.get<DijService>();
  final List<String> _ciclos = [
    'Primeiro Ciclo',
    'Segundo Ciclo',
    'Terceiro Ciclo',
    'Grupo de Pais',
    'Pós Juventude'
  ];

  DateTime? _dataSelecionada;
  Future<List<DateTime>>? _datasFuture;
  Map<String, String> _jovemIdToName = {};

  @override
  void initState() {
    super.initState();
    _datasFuture = _dijService.getUltimasDatasDeChamada();
    _datasFuture!.then((datas) {
      if (datas.isNotEmpty && mounted) {
        setState(() {
          _dataSelecionada = datas.first;
        });
      }
    });
    // Carrega o mapa de jovens para referência
    _dijService.getJovens().first.then((jovens) {
      if (mounted) {
        setState(() {
          _jovemIdToName = {for (var j in jovens) j.id!: j.nome};
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard DIJ'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildGraficoAlunosPorCiclo(),
          const SizedBox(height: 24),
          _buildFiltroDeData(),
          const SizedBox(height: 16),
          _buildGridUltimasChamadas(),
        ],
      ),
    );
  }

  Widget _buildFiltroDeData() {
    return FutureBuilder<List<DateTime>>(
      future: _datasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _dataSelecionada == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final datas = snapshot.data!;
        return DropdownButtonFormField<DateTime>(
          value: _dataSelecionada,
          decoration: const InputDecoration(
            labelText: 'Filtrar Chamadas por Data',
            border: OutlineInputBorder(),
          ),
          items: datas.map((data) {
            return DropdownMenuItem<DateTime>(
              value: data,
              child: Text(DateFormat('dd/MM/yyyy').format(data)),
            );
          }).toList(),
          onChanged: (data) {
            if (data != null) {
              setState(() => _dataSelecionada = data);
            }
          },
        );
      },
    );
  }

  Widget _buildGraficoAlunosPorCiclo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total de Jovens por Ciclo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: FutureBuilder<Map<String, int>>(
                future: _dijService.getJovensCountPorCiclo(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum jovem cadastrado.'));
                  }

                  final data = snapshot.data!;
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: data.entries.map((entry) {
                        final index = _ciclos.indexOf(entry.key);
                        if (index == -1) return null;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: Colors.blue,
                              width: 20,
                              borderRadius: BorderRadius.zero,
                            ),
                          ],
                        );
                      }).whereType<BarChartGroupData>().toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _ciclos.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(_ciclos[index].replaceAll(' ', '\n'), style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridUltimasChamadas() {
    if (_dataSelecionada == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Selecione uma data para ver as chamadas.'),
        ),
      );
    }

    return FutureBuilder<List<ChamadaDij>>(
      key: ValueKey(_dataSelecionada),
      future: _dijService.getChamadasPorData(_dataSelecionada!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chamadasDoDia = snapshot.data ?? [];

        return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 1.0 : 1.0,
                ),
                itemCount: _ciclos.length,
                itemBuilder: (context, index) {
                  final ciclo = _ciclos[index];
                  final chamada = chamadasDoDia.firstWhere(
                        (c) => c.ciclo == ciclo,
                    // CORRIGIDO: Usa 'presencas'
                    orElse: () => ChamadaDij(id: '', ciclo: ciclo, data: _dataSelecionada!, responsavelNome: '', presencas: {}),
                  );

                  return _ChamadaCard(chamada: chamada, jovemIdToName: _jovemIdToName);
                },
              );
            }
        );
      },
    );
  }
}

class _ChamadaCard extends StatelessWidget {
  final ChamadaDij chamada;
  final Map<String, String> jovemIdToName;
  const _ChamadaCard({required this.chamada, required this.jovemIdToName});

  @override
  Widget build(BuildContext context) {
    // CORRIGIDO: Usa 'presencas'
    final _ = chamada.presencas.keys
        .map((id) => jovemIdToName[id] ?? 'Jovem não encontrado ($id)')
        .toList()..sort();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chamada.ciclo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (chamada.id.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                child: Text(
                  'Por: ${chamada.responsavelNome}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            const Divider(),
            if (chamada.id.isEmpty)
              const Expanded(
                child: Center(child: Text('Sem chamada neste dia', textAlign: TextAlign.center)),
              )
            else
              Expanded(
                child: ListView(
                  children: chamada.presencas.entries.map((entry) {
                    final nomeDoJovem = jovemIdToName[entry.key] ?? 'Jovem não encontrado';
                    final isPresente = entry.value;
                    return ListTile(
                      title: Text(nomeDoJovem, style: const TextStyle(fontSize: 14)),
                      trailing: Checkbox(
                        value: isPresente,
                        onChanged: null,
                      ),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList()..sort((a, b) => (a.title as Text).data!.compareTo((b.title as Text).data!)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}