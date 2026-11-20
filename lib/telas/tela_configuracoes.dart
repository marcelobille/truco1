import 'package:flutter/material.dart';

import '../modelos/configuracoes.dart';

class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  late int pontos;
  late int segundos;

  @override
  void initState() {
    super.initState();
    pontos = ConfiguracoesPartida.pontosParaVencer;
    segundos = ConfiguracoesPartida.segundosPorJogada;
  }

  void _salvar() {
    ConfiguracoesPartida.pontosParaVencer = pontos;
    ConfiguracoesPartida.segundosPorJogada = segundos;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D2A),
      appBar: AppBar(
        title: const Text('CONFIGURAÇÕES'),
        backgroundColor: const Color(0xFF082719),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'CONFIGURAÇÕES DA PARTIDA',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _SettingCard(
            title: 'Pontos para vencer a partida',
            description: 'Escolha a pontuação necessária para ganhar.',
            child: DropdownButton<int>(
              value: pontos,
              isExpanded: true,
              dropdownColor: const Color(0xFF174B35),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: const [6, 9, 12].map((v) {
                return DropdownMenuItem(value: v, child: Text('$v pontos'));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => pontos = v);
              },
            ),
          ),
          const SizedBox(height: 14),
          _SettingCard(
            title: 'Tempo para jogar',
            description: 'Tempo disponível para cada jogada.',
            child: DropdownButton<int>(
              value: segundos,
              isExpanded: true,
              dropdownColor: const Color(0xFF174B35),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: const [15, 20, 30, 45, 60].map((v) {
                return DropdownMenuItem(value: v, child: Text('$v segundos'));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => segundos = v);
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.save),
              label: const Text(
                'SALVAR CONFIGURAÇÕES',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'As opções salvas serão usadas nas próximas partidas. '
            'Nesta primeira etapa, estão disponíveis a pontuação final '
            'e o tempo de cada jogada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _SettingCard({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF082719),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
