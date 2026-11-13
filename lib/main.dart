
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const TrucoApp());

class TrucoApp extends StatelessWidget {
  const TrucoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Truco Mineiro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b42)),
      useMaterial3: true,
    ),
    home: const TablePage(),
  );
}

class PlayingCard {
  final String rank, suit;
  const PlayingCard(this.rank, this.suit);
  String get label => '$rank$suit';
}

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final roomController = TextEditingController(text: 'TRUCO7');
  final random = Random();

  Timer? timer;

  List<PlayingCard> myCards = [];
  List<PlayingCard> played = [];
  List<PlayingCard> burned = [];
  List<List<PlayingCard>> hands = [[], [], [], []];

  List<String> players = [
    'Você', 'Aguardando', 'Aguardando', 'Aguardando'
  ];

  bool roomReady = false;
  bool started = false;
  String status = 'Crie uma sala para começar.';
  String phase = 'parado';

  int countdown = 0;
  int burnCount = 0;

  String? selectedShuffle;
  String? selectedCut;

  final shuffleOptions = [
    'Por cima',
    'Por baixo',
    'Intercalado',
    'Aleatório',
  ];

  final cutOptions = [
    'Simples',
    'Duplo',
    'Aleatório',
  ];

  List<PlayingCard> makeDeck() {
    const ranks = ['4', '5', '6', '7', 'Q', 'J', 'K', 'A', '2', '3'];
    const suits = ['♣', '♥', '♠', '♦'];

    return [
      for (final suit in suits)
        for (final rank in ranks)
          PlayingCard(rank, suit),
    ];
  }

  void createRoom() {
    setState(() {
      roomReady = true;
      status = 'Sala criada: ${roomController.text.toUpperCase()}';
    });
  }

  void joinRoom() {
    setState(() {
      roomReady = true;
      status = 'Entrada demonstrativa. Ainda não conecta celulares.';
    });
  }

  void fillBots() {
    setState(() {
      players = ['Você', 'Bot 1', 'Bot 2', 'Bot 3'];
      status = 'Mesa completa: você e três bots.';
    });
  }

  void startPreparation() {
    if (!roomReady) return;

    timer?.cancel();

    setState(() {
      started = false;
      myCards = [];
      played = [];
      burned = [];
      hands = [[], [], [], []];
      selectedShuffle = null;
      selectedCut = null;
      burnCount = 0;
      phase = 'embaralhar';
      countdown = 5;
      status = 'Distribuidor: escolha o embaralhamento.';
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() {
        countdown--;

        if (countdown <= 0) {
          advancePreparation();
        }
      });
    });
  }

  void advancePreparation() {
    if (phase == 'embaralhar') {
      selectedShuffle ??=
          shuffleOptions[random.nextInt(shuffleOptions.length)];

      phase = 'cortar';
      countdown = 5;
      status = 'Cortador: escolha o tipo de corte.';
    } else if (phase == 'cortar') {
      selectedCut ??=
          cutOptions[random.nextInt(cutOptions.length)];

      phase = 'queimar';
      countdown = 3;
      status = 'Jogador mão: escolha quantas cartas queimar.';
    } else if (phase == 'queimar') {
      // Se não houver escolha, burnCount permanece zero.
      timer?.cancel();
      distributeCards();
    }
  }

  void chooseShuffle(String option) {
    if (phase != 'embaralhar') return;
    setState(() {
      selectedShuffle = option;
      status = 'Embaralhamento escolhido: $option';
    });
  }

  void chooseCut(String option) {
    if (phase != 'cortar') return;
    setState(() {
      selectedCut = option;
      status = 'Corte escolhido: $option';
    });
  }

  void chooseBurn(int amount) {
    if (phase != 'queimar') return;
    setState(() {
      burnCount = amount;
      status = amount == 0
          ? 'Você escolheu não queimar cartas.'
          : 'Você escolheu queimar $amount cartas.';
    });
  }

  List<PlayingCard> shuffleDeck(
    List<PlayingCard> deck,
    String method,
  ) {
    final cards = List<PlayingCard>.from(deck);

    if (method == 'Por cima') {
      final result = <PlayingCard>[];
      while (cards.isNotEmpty) {
        final size = min(cards.length, random.nextInt(5) + 1);
        result.insertAll(0, cards.sublist(0, size));
        cards.removeRange(0, size);
      }
      return result;
    }

    if (method == 'Por baixo') {
      final result = <PlayingCard>[];
      while (cards.isNotEmpty) {
        final size = min(cards.length, random.nextInt(5) + 1);
        result.addAll(cards.sublist(0, size));
        cards.removeRange(0, size);
      }
      return result;
    }

    if (method == 'Intercalado') {
      final middle = cards.length ~/ 2;
      final left = cards.sublist(0, middle);
      final right = cards.sublist(middle);
      final result = <PlayingCard>[];

      while (left.isNotEmpty || right.isNotEmpty) {
        if (left.isNotEmpty) {
          final count = min(left.length, random.nextInt(3) + 1);
          result.addAll(left.take(count));
          left.removeRange(0, count);
        }
        if (right.isNotEmpty) {
          final count = min(right.length, random.nextInt(3) + 1);
          result.addAll(right.take(count));
          right.removeRange(0, count);
        }
      }
      return result;
    }

    return cards..shuffle(random);
  }

  List<PlayingCard> cutDeck(
    List<PlayingCard> deck,
    String method,
  ) {
    final cards = List<PlayingCard>.from(deck);

    if (method == 'Simples') {
      final point = random.nextInt(cards.length - 1) + 1;
      return [...cards.sublist(point), ...cards.sublist(0, point)];
    }

    if (method == 'Duplo') {
      for (var i = 0; i < 2; i++) {
        final point = random.nextInt(cards.length - 1) + 1;
        final first = cards.sublist(0, point);
        final second = cards.sublist(point);
        cards
          ..clear()
          ..addAll(second)
          ..addAll(first);
      }
      return cards;
    }

    final point = random.nextInt(cards.length - 1) + 1;
    return [...cards.sublist(point), ...cards.sublist(0, point)];
  }

  void distributeCards() {
    var deck = makeDeck();

    deck = shuffleDeck(deck, selectedShuffle!);
    deck = cutDeck(deck, selectedCut!);

    final amount = min(burnCount, deck.length - 12);

    burned = deck.take(amount).toList();
    deck.removeRange(0, amount);

    hands = [[], [], [], []];

    // Distribui três cartas para cada um dos quatro jogadores.
    for (var card = 0; card < 3; card++) {
      for (var player = 0; player < 4; player++) {
        hands[player].add(deck.removeAt(0));
      }
    }

    setState(() {
      myCards = List<PlayingCard>.from(hands[0]);
      played = [];
      started = true;
      phase = 'finalizado';
      countdown = 0;

      status = 'Cartas distribuídas! '
          'Embaralhamento: $selectedShuffle. '
          'Corte: $selectedCut. '
          'Cartas queimadas: $amount.';
    });
  }

  void playCard(int index) {
    if (!started || index >= myCards.length) return;

    setState(() {
      final card = myCards.removeAt(index);
      played.add(card);
      status = 'Você jogou ${card.label}.';
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff102f25),
      appBar: AppBar(
        title: const Text('TRUCO MINEIRO'),
        centerTitle: true,
        backgroundColor: const Color(0xff0b241c),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xff1d6847),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'SALA ONLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: roomController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Código da sala',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: createRoom,
                        child: const Text('Criar sala'),
                      ),
                      OutlinedButton(
                        onPressed: joinRoom,
                        child: const Text('Entrar na sala'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff17613e),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xff8ac7a4),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'MESA — 4 JOGADORES / 2 DUPLAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  seat(players[1], 'Dupla adversária'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      seat(players[2], 'Sua dupla'),
                      seat(players[0], 'Você'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xff0d4a32),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: played.isEmpty
                          ? const Text(
                              'Cartas jogadas aparecem aqui',
                              style: TextStyle(color: Colors.white70),
                            )
                          : Wrap(
                              spacing: 8,
                              children: played
                                  .map((c) => cardWidget(c, small: true))
                                  .toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  seat(players[3], 'Dupla adversária'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            FilledButton.tonal(
              onPressed: roomReady ? fillBots : null,
              child: const Text('Completar com bots'),
            ),

            const SizedBox(height: 8),

            FilledButton(
              onPressed: roomReady && phase != 'embaralhar' &&
                      phase != 'cortar' && phase != 'queimar'
                  ? startPreparation
                  : null,
              child: const Text('Iniciar preparação da partida'),
            ),

            const SizedBox(height: 16),

            if (phase == 'embaralhar' ||
                phase == 'cortar' ||
                phase == 'queimar') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xff1d6847),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      phase == 'embaralhar'
                          ? 'ESCOLHA O EMBARALHAMENTO'
                          : phase == 'cortar'
                              ? 'ESCOLHA O CORTE'
                              : 'QUEIMAR CARTAS?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$countdown segundos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (phase == 'embaralhar')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: shuffleOptions.map((option) {
                          return ChoiceChip(
                            label: Text(option),
                            selected: selectedShuffle == option,
                            onSelected: (_) => chooseShuffle(option),
                          );
                        }).toList(),
                      ),

                    if (phase == 'cortar')
                      Wrap(
                        spacing: 8,
                        children: cutOptions.map((option) {
                          return ChoiceChip(
                            label: Text(option),
                            selected: selectedCut == option,
                            onSelected: (_) => chooseCut(option),
                          );
                        }).toList(),
                      ),

                    if (phase == 'queimar')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(10, (number) {
                          return ChoiceChip(
                            label: Text('$number'),
                            selected: burnCount == number,
                            onSelected: (_) => chooseBurn(number),
                          );
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Text(
              'SUAS CARTAS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (myCards.isEmpty)
              const Text(
                'As cartas aparecerão aqui depois da distribuição.',
                style: TextStyle(color: Colors.white70),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  myCards.length,
                  (i) => InkWell(
                    onTap: () => playCard(i),
                    child: cardWidget(myCards[i]),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Text(
              'Cartas queimadas: ${burned.length}',
              style: const TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Primeira etapa: preparação e distribuição local. '
              'Conexão entre celulares e bots jogando serão '
              'implementados nas próximas etapas.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget seat(String name, String role) => Column(
    children: [
      const CircleAvatar(
        backgroundColor: Color(0xffd7e8d9),
        child: Icon(Icons.person, color: Color(0xff16452f)),
      ),
      const SizedBox(height: 4),
      Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        role,
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
    ],
  );

  Widget cardWidget(PlayingCard card, {bool small = false}) {
    final red = card.suit == '♥' || card.suit == '♦';

    return Container(
      width: small ? 48 : 76,
      height: small ? 68 : 108,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xfffffdf4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.label,
          style: TextStyle(
            fontSize: small ? 18 : 28,
            fontWeight: FontWeight.bold,
            color: red ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
