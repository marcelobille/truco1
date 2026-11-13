
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff146b42),
      ),
      useMaterial3: true,
    ),
    home: const TablePage(),
  );
}

class PlayingCard {
  final String rank;
  final String suit;
  const PlayingCard(this.rank, this.suit);
  String get label => '$rank$suit';
}

class CardPlay {
  final PlayingCard card;
  final int player;
  const CardPlay(this.card, this.player);
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

  List<String> players = [
    'Você', 'Bot 1', 'Bot 2', 'Bot 3'
  ];

  List<List<PlayingCard>> hands = [
    [], [], [], []
  ];

  List<PlayingCard> myCards = [];
  List<CardPlay> trick = [];
  List<PlayingCard> discardPile = [];
  List<int> trickWinners = [];

  bool roomReady = false;
  bool started = false;
  bool busy = false;

  String status = 'Crie uma sala para começar.';
  String phase = 'parado';

  int countdown = 0;
  int burnCount = 0;
  int currentPlayer = 0;

  int pointsTeam0 = 0;
  int pointsTeam1 = 0;
  int matchWins0 = 0;
  int matchWins1 = 0;
  int matchNumber = 1;
  int handValue = 2;

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
    const ranks = [
      '4', '5', '6', '7', 'Q',
      'J', 'K', 'A', '2', '3'
    ];

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
      status = 'Sala demonstrativa. Modo local.';
    });
  }

  void fillBots() {
    setState(() {
      players = ['Você', 'Bot 1', 'Bot 2', 'Bot 3'];
      roomReady = true;
      status = 'Mesa completa: você e três bots.';
    });
  }

  void startPreparation() {
    if (!roomReady) return;

    timer?.cancel();

    setState(() {
      started = false;
      busy = false;
      hands = [[], [], [], []];
      myCards = [];
      trick = [];
      trickWinners = [];
      selectedShuffle = null;
      selectedCut = null;
      burnCount = 0;
      handValue = 2;
      phase = 'embaralhar';
      countdown = 5;
      status = 'Distribuidor: escolha o embaralhamento.';
    });

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (countdown <= 1) {
          t.cancel();
          advancePreparation();
        } else {
          setState(() {
            countdown--;
          });
        }
      },
    );
  }

  void advancePreparation() {
    if (phase == 'embaralhar') {
      setState(() {
        selectedShuffle ??=
            shuffleOptions[random.nextInt(shuffleOptions.length)];
        phase = 'cortar';
        countdown = 5;
        status = 'Cortador: escolha o tipo de corte.';
      });
      startCountdown();
    } else if (phase == 'cortar') {
      setState(() {
        selectedCut ??=
            cutOptions[random.nextInt(cutOptions.length)];
        phase = 'queimar';
        countdown = 5;
        status = 'Jogador mão: escolha de 0 a 9 cartas.';
      });
      startCountdown();
    } else if (phase == 'queimar') {
      timer?.cancel();
      distributeCards();
    }
  }

  void startCountdown() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (countdown <= 1) {
          t.cancel();
          advancePreparation();
        } else {
          setState(() {
            countdown--;
          });
        }
      },
    );
  }

  void chooseShuffle(String option) {
    if (phase != 'embaralhar') return;

    setState(() {
      selectedShuffle = option;
      status = 'Embaralhamento: $option';
    });
  }

  void chooseCut(String option) {
    if (phase != 'cortar') return;

    setState(() {
      selectedCut = option;
      status = 'Corte: $option';
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
          final n = min(left.length, random.nextInt(3) + 1);
          result.addAll(left.take(n));
          left.removeRange(0, n);
        }

        if (right.isNotEmpty) {
          final n = min(right.length, random.nextInt(3) + 1);
          result.addAll(right.take(n));
          right.removeRange(0, n);
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

    int cut() => random.nextInt(cards.length - 1) + 1;

    if (method == 'Duplo') {
      for (int i = 0; i < 2; i++) {
        final point = cut();
        final first = cards.sublist(0, point);
        final second = cards.sublist(point);

        cards
          ..clear()
          ..addAll(second)
          ..addAll(first);
      }

      return cards;
    }

    final point = cut();

    return [
      ...cards.sublist(point),
      ...cards.sublist(0, point),
    ];
  }

  void distributeCards() {
    var deck = makeDeck();

    deck = shuffleDeck(
      deck,
      selectedShuffle ?? 'Aleatório',
    );

    deck = cutDeck(
      deck,
      selectedCut ?? 'Aleatório',
    );

    final amount = min(burnCount, deck.length - 12);

    final burned = deck.take(amount).toList();
    deck.removeRange(0, amount);

    hands = [[], [], [], []];
    discardPile = [...burned];
    trick = [];
    trickWinners = [];

    for (int card = 0; card < 3; card++) {
      for (int player = 0; player < 4; player++) {
        hands[player].add(deck.removeAt(0));
      }
    }

    setState(() {
      myCards = List.from(hands[0]);
      currentPlayer = 0;
      started = true;
      busy = false;
      phase = 'finalizado';

      status = 'Cartas distribuídas! '
          'Queimadas: $amount. '
          'Sua vez de jogar.';
    });
  }

  int cardPower(PlayingCard card) {
    if (card.rank == '4' && card.suit == '♣') return 104;
    if (card.rank == '7' && card.suit == '♥') return 103;
    if (card.rank == 'A' && card.suit == '♠') return 102;
    if (card.rank == '7' && card.suit == '♦') return 101;

    const normalOrder = {
      '4': 1,
      '5': 2,
      '6': 3,
      '7': 4,
      'Q': 5,
      'J': 6,
      'K': 7,
      'A': 8,
      '2': 9,
      '3': 10,
    };

    return normalOrder[card.rank] ?? 0;
  }

  void playCard(int index) {
    if (!started ||
        busy ||
        currentPlayer != 0 ||
        index < 0 ||
        index >= myCards.length) {
      return;
    }

    playForPlayer(0, index);
  }

  void playForPlayer(int player, int index) {
    if (!started || hands[player].isEmpty) return;

    final card = hands[player].removeAt(index);

    setState(() {
      if (player == 0) {
        myCards = List.from(hands[0]);
      }

      trick.add(CardPlay(card, player));
      discardPile.add(card);
      status = '${players[player]} jogou ${card.label}.';
    });

    if (trick.length == 4) {
      finishTrick();
    } else {
      currentPlayer = (player + 1) % 4;

      if (currentPlayer != 0) {
        scheduleBot();
      } else {
        setState(() {
          status = 'Sua vez de jogar.';
        });
      }
    }
  }

  void scheduleBot() {
    if (!started || currentPlayer == 0) return;

    busy = true;

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !started || currentPlayer == 0) return;

      final player = currentPlayer;
      final cards = hands[player];

      if (cards.isEmpty) return;

      int chosenIndex = 0;

      if (random.nextDouble() < 0.7) {
        for (int i = 1; i < cards.length; i++) {
          if (cardPower(cards[i]) > cardPower(cards[chosenIndex])) {
            chosenIndex = i;
          }
        }
      } else {
        chosenIndex = random.nextInt(cards.length);
      }

      busy = false;
      playForPlayer(player, chosenIndex);
    });
  }

  void finishTrick() {
    if (trick.length != 4) return;

    int winner = trick.first.player;
    int bestPower = -1;

    for (final play in trick) {
      final power = cardPower(play.card);

      if (power > bestPower) {
        bestPower = power;
        winner = play.player;
      }
    }

    trickWinners.add(winner);

    setState(() {
      status = '${players[winner]} venceu esta rodada!';
    });

    final team0Wins =
        trickWinners.where((p) => p % 2 == 0).length;

    final team1Wins =
        trickWinners.where((p) => p % 2 == 1).length;

    if (team0Wins >= 2 ||
        team1Wins >= 2 ||
        trickWinners.length == 3) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) finishHand();
      });
      return;
    }

    currentPlayer = winner;

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || !started) return;

      setState(() {
        trick = [];
        status = 'Nova rodada. Começa ${players[currentPlayer]}.';
      });

      if (currentPlayer != 0) {
        scheduleBot();
      }
    });
  }

  void finishHand() {
    final team0Wins =
        trickWinners.where((p) => p % 2 == 0).length;

    final team1Wins =
        trickWinners.where((p) => p % 2 == 1).length;

    int winner;

    if (team0Wins > team1Wins) {
      winner = 0;
    } else if (team1Wins > team0Wins) {
      winner = 1;
    } else {
      winner = trickWinners.isEmpty
          ? 0
          : trickWinners.first % 2;
    }

    final earned = handValue;

    setState(() {
      if (winner == 0) {
        pointsTeam0 += earned;
        status = 'Sua dupla venceu a mão! +$earned pontos.';
      } else {
        pointsTeam1 += earned;
        status = 'Dupla adversária venceu! +$earned pontos.';
      }

      started = false;
      busy = false;
      trick = [];
      myCards = [];
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) checkMatch();
    });
  }

  void checkMatch() {
    if (pointsTeam0 >= 12 || pointsTeam1 >= 12) {
      final winner = pointsTeam0 >= 12 ? 0 : 1;

      setState(() {
        if (winner == 0) {
          matchWins0++;
        } else {
          matchWins1++;
        }

        status = winner == 0
            ? 'Sua dupla venceu a partida $matchNumber!'
            : 'Os adversários venceram a partida $matchNumber!';

        pointsTeam0 = 0;
        pointsTeam1 = 0;
      });

      if (matchWins0 >= 2 || matchWins1 >= 2) {
        setState(() {
          status = matchWins0 >= 2
              ? 'CAMPEÃO! Sua dupla venceu o melhor de três!'
              : 'Fim de jogo! Os bots venceram o melhor de três!';

          phase = 'fim';
        });

        return;
      }

      matchNumber++;
    }

    startPreparation();
  }

  void requestTruco() {
    if (!started || busy || handValue >= 12) return;

    final nextValues = [2, 4, 6, 10, 12];
    final currentIndex = nextValues.indexOf(handValue);

    if (currentIndex < 0 || currentIndex >= 4) return;

    final newValue = nextValues[currentIndex + 1];

    setState(() {
      handValue = newValue;
      status = 'Você pediu truco! Valor da mão: $handValue pontos.';
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !started) return;

      final accepted = random.nextDouble() < 0.8;

      setState(() {
        if (accepted) {
          status = 'Os bots aceitaram! Vale $handValue pontos.';
        } else {
          pointsTeam0 += handValue ~/ 2;
          status = 'Os bots correram! Sua dupla ganhou '
              '${handValue ~/ 2} pontos.';
        }
      });

      if (!accepted) {
        started = false;
        checkMatch();
      }
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
                    'SALA ONLINE — MODO LOCAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextField(
                    controller: roomController,
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xff17613e),
                borderRadius: BorderRadius.circular(18),
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
                  const SizedBox(height: 12),
                  seat(players[1], 'Dupla adversária'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      seat(players[2], 'Sua dupla'),
                      seat(players[0], 'Você'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 115,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xff0d4a32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: trick.isEmpty
                          ? const Text(
                              'Mesa de cartas',
                              style: TextStyle(color: Colors.white70),
                            )
                          : Wrap(
                              spacing: 8,
                              children: trick.map((p) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    cardWidget(p.card, small: true),
                                    Text(
                                      players[p.player],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  seat(players[3], 'Dupla adversária'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PLACAR — PARTIDA $matchNumber DE 3',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Sua dupla: $pointsTeam0   x   Adversários: $pointsTeam1',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Partidas vencidas: $matchWins0 x $matchWins1',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: roomReady ? fillBots : null,
              child: const Text('Completar com bots'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: roomReady &&
                      phase != 'embaralhar' &&
                      phase != 'cortar' &&
                      phase != 'queimar' &&
                      phase != 'fim'
                  ? startPreparation
                  : null,
              child: const Text('Iniciar preparação'),
            ),
            const SizedBox(height: 12),
            if (phase == 'embaralhar' ||
                phase == 'cortar' ||
                phase == 'queimar')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff1d6847),
                  borderRadius: BorderRadius.circular(12),
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
                    Text(
                      '$countdown segundos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (phase == 'embaralhar')
                      Wrap(
                        spacing: 6,
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
                        spacing: 6,
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
                        spacing: 5,
                        children: List.generate(10, (n) {
                          return ChoiceChip(
                            label: Text('$n'),
                            selected: burnCount == n,
                            onSelected: (_) => chooseBurn(n),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
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
                'Suas cartas aparecerão aqui.',
                style: TextStyle(color: Colors.white70),
              )
            else
              Wrap(
                spacing: 10,
                children: List.generate(
                  myCards.length,
                  (i) => InkWell(
                    onTap: () => playCard(i),
                    child: cardWidget(myCards[i]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (started)
              FilledButton(
                onPressed: requestTruco,
                child: const Text('PEDIR TRUCO'),
              ),
            const SizedBox(height: 10),
            Text(
              'Monte de descarte: ${discardPile.length} cartas',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            const Text(
              'Versão local de desenvolvimento. '
              'Bots, jogadas e pontuação em implementação. '
              'Conexão online será uma etapa futura.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
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
        child: Icon(
          Icons.person,
          color: Color(0xff16452f),
        ),
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
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
        ),
      ),
    ],
  );

  Widget cardWidget(
    PlayingCard card, {
    bool small = false,
  }) {
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
