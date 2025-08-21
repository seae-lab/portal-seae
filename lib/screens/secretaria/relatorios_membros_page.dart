import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class RelatoriosMembrosPage extends StatelessWidget {
  const RelatoriosMembrosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultas e Relatórios'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionTitle(context, 'Consultas Gerais', Icons.search),
          const SizedBox(height: 16),
          _buildReportCard(
            context: context,
            title: 'Consulta Avançada na Base de Dados',
            subtitle: 'Realize buscas com múltiplos filtros e gere PDFs.',
            icon: Icons.filter_alt_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/consulta_avancada');
            },
          ),
          _buildReportCard(
            context: context,
            title: 'Controle de Contribuições Mensais',
            subtitle: 'Visualize a tabela de contribuições anuais dos sócios.',
            icon: Icons.grid_on_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/controle_contribuicoes');
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Documentos de Membros', Icons.description_outlined), // NOVO
          const SizedBox(height: 16),
          _buildReportCard( // NOVO
            context: context,
            title: 'Gerar Proposta Social',
            subtitle: 'Preenche e imprime a Proposta Social de um membro.',
            icon: Icons.person_add_alt_1_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/proposta_social');
            },
          ),
          _buildReportCard( // NOVO
            context: context,
            title: 'Gerar Termo de Adesão',
            subtitle: 'Preenche e imprime o Termo de Adesão de um voluntário.',
            icon: Icons.file_present_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/termo_adesao');
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Relatórios Estatutários', Icons.gavel_outlined),
          const SizedBox(height: 16),
          _buildReportCard(
            context: context,
            title: 'Sócios Efetivos Elegíveis a Conselheiro',
            subtitle: 'Relação de sócios que podem exercer o cargo de conselheiro.',
            icon: Icons.school_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/socios_elegiveis');
            },
          ),
          _buildReportCard(
            context: context,
            title: 'Sócios Promovíveis',
            subtitle: 'Relação de sócios colaboradores aptos a se tornarem efetivos.',
            icon: Icons.arrow_upward_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/socios_promoviveis');
            },
          ),
          _buildReportCard(
            context: context,
            title: 'Sócios Votantes',
            subtitle: 'Relação de sócios efetivos aptos a votar (base: 31 de Agosto).',
            icon: Icons.how_to_vote_outlined,
            onTap: () {
              Modular.to.pushNamed('/home/socios_votantes');
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Relatórios Administrativos', Icons.admin_panel_settings_outlined),
          const SizedBox(height: 16),
          _buildReportCard(
            context: context,
            title: 'Colaboradores por Departamento',
            subtitle: 'Relação de voluntários e sócios por unidade operacional.',
            icon: Icons.workspaces_outline,
            onTap: () {
              Modular.to.pushNamed('/home/colaboradores_departamento');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(icon, size: 26, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}