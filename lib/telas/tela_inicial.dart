import 'package:flutter/material.dart';

import 'tela_configuracoes.dart';

class TelaInicial extends StatelessWidget {
  final VoidCallback onMineiroPressed;

  const TelaInicial({super.key, required this.onMineiroPressed});

  void _abrirJogo(BuildContext context, String modalidade) {
    if (modalidade == 'paulista') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O Truco Paulista será desenvolvido na próxima etapa.'),
        ),
      );
      return;
    }

    onMineiroPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D2A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/imagens/icone_truco.png',
                      width: 190,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.style,
                        color: Colors.amber,
                        size: 130,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'TRUCO ZAP REAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escolha como deseja jogar',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 30),
                  _MenuButton(
                    title: 'TRUCO MINEIRO',
                    icon: Icons.sports_esports,
                    onPressed: () => _abrirJogo(context, 'mineiro'),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    title: 'TRUCO PAULISTA',
                    icon: Icons.style,
                    onPressed: () => _abrirJogo(context, 'paulista'),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    title: 'CONFIGURAÇÕES',
                    icon: Icons.settings,
                    secondary: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelaConfiguracoes(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;
  final bool secondary;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary ? const Color(0xFF34443D) : const Color(0xFF236344),
          foregroundColor: secondary ? Colors.white : Colors.amber,
          side: const BorderSide(color: Colors.amber, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
