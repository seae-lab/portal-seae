// lib/screens/home/pages/secretaria/relatorios_membros_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class RelatoriosMembrosPage extends StatelessWidget {
  const RelatoriosMembrosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultas, Relatórios e Formulários'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionTitle(context, 'Consultas e Relatórios', Icons.search),
          const SizedBox(height: 16),
          _buildReportCard(
            title: 'Consulta Avançada na Base de Dados',
            subtitle: 'Realize buscas com múltiplos filtros e gere PDFs.',
            icon: Icons.filter_alt_outlined,
            onTap: () {
              Modular.to.navigate('/home/consulta_avancada');
            },
          ),
          _buildReportCard(
            title: 'Controle de Contribuições Mensais',
            subtitle: 'Visualize a tabela de contribuições anuais dos sócios.',
            icon: Icons.grid_on_outlined,
            onTap: () {
              // ATUALIZADO: Navega para a nova rota
              Modular.to.navigate('/home/controle_contribuicoes');
            },
          ),
          _buildReportCard(
            title: 'Sócios Efetivos Elegíveis a Conselheiro',
            subtitle: 'Gera a relação de sócios aptos para o conselho.',
            icon: Icons.school_outlined,
            onTap: () {
              // TODO: Implementar lógica de geração de PDF
            },
          ),
          // ... (restante dos seus cards)
        ],
      ),
    );
  }

  // Seus outros widgets (_buildSectionTitle, _buildReportCard) permanecem aqui
  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}