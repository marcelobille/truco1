import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const TrucoApp());

class TrucoApp extends StatelessWidget {
  const TrucoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TrucoZap',
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
  bool roomReady = false;
  bool started = false;
  bool busy = false;
  bool showBurned = false;

  String status = 'Crie uma sala para começar.';
  String phase = 'parado';

  int countdown = 0;
  int burnCount = 0;
  int currentPlayer = 0;
  int dealProgress = 0;

  int pointsTeam0 = 0;
  int pointsTeam1 = 0;
  int matchWins0 = 0;
  int matchWins1 = 0;
  int matchNumber = 1;
  int handValue = 2;

  String? selectedShuffle;
  String? selectedCut;

  final List<String> players = [
    'Você',
    'Bot 2',
    'Sua dupla',
    'Bot 3',
  ];

  List<List<PlayingCard>> hands = [[], [], [], []];
  List<PlayingCard> myCards = [];
  List<CardPlay> trick = [];
  List<PlayingCard> discardPile = [];
  List<PlayingCard> playedPile = [];
  List<PlayingCard> burnedCards = [];
  List<int> trickWinners = [];

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
      'J', 'K', 'A', '2', '3',
    ];
    const suits = ['♣', '♥', '♠', '♦'];

    return [
      for (final suit in suits)
        for (final rank in ranks) PlayingCard(rank, suit),
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
      showBurned = false;
      burnedCards = [];
      hands = [[], [], [], []];
      myCards = [];
      trick = [];
      discardPile = [];
      playedPile = [];
      trickWinners = [];
      selectedShuffle = null;
      selectedCut = null;
      burnCount = 0;
      dealProgress = 0;
      handValue = 2;
      phase = 'embaralhar';
      countdown = 5;
      status = 'Pé: escolha o embaralhamento.';
    });
    startCountdown();
  }

  void startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (countdown <= 1) {
        t.cancel();
        advancePreparation();
      } else {
        setState(() => countdown--);
      }
    });
  }

  void advancePreparation() {
    if (phase == 'embaralhar') {
      setState(() {
        selectedShuffle ??=
            shuffleOptions[random.nextInt(shuffleOptions.length)];
        phase = 'cortar';
        countdown = 5;
        status = 'Antepé: escolha o corte.';
      });
      startCountdown();
    } else if (phase == 'cortar') {
      setState(() {
        selectedCut ??= cutOptions[random.nextInt(cutOptions.length)];
        phase = 'queimar';
        countdown = 5;
        status = 'Mão: escolha quantas cartas queimar.';
      });
      startCountdown();
    } else if (phase == 'queimar') {
      timer?.cancel();
      distributeCards();
    }
  }

  void chooseShuffle(String option) {
    if (phase != 'embaralhar') return;
    setState(() {
      selectedShuffle = option;
      status = 'Embaralhamento escolhido: $option.';
    });
  }

  void chooseCut(String option) {
    if (phase != 'cortar') return;

    timer?.cancel();
    setState(() {
      selectedCut = option;
      status = option == 'Não cortar'
          ? 'O baralho não será cortado.'
          : 'Corte escolhido: $option.';
      phase = 'queimar';
      countdown = 5;
    });

    if (option == 'Não cortar') {
      setState(() {
        status = 'Sem corte. Mão: escolha a queima.';
      });
      startCountdown();
    } else {
      startCountdown();
    }
  }

  void chooseBurn(int amount) {
    if (phase != 'queimar') return;

    timer?.cancel();
    setState(() {
      burnCount = amount;
      status = amount == 0
          ? 'Você escolheu não queimar cartas.'
          : 'Você escolheu queimar $amount cartas.';
    });

    if (amount == 0) {
      distributeCards();
    } else {
      // A seleção fica visível durante a contagem; ao terminar,
      // as cartas queimadas aparecem no centro antes da distribuição.
      countdown = 2;
      startCountdown();
    }
  }

  List<PlayingCard> shuffleDeck(List<PlayingCard> deck, String method) {
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

  List<PlayingCard> cutDeck(List<PlayingCard> deck, String method) {
    final cards = List<PlayingCard>.from(deck);
    if (method == 'Não cortar') return cards;

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

  Future<void> distributeCards() async {
    timer?.cancel();

    var deck = makeDeck();
    deck = shuffleDeck(deck, selectedShuffle ?? 'Aleatório');
    deck = cutDeck(deck, selectedCut ?? 'Aleatório');

    final amount = min(burnCount, deck.length - 12);
    final burned = deck.take(amount).toList();
    deck.removeRange(0, amount);

    setState(() {
      hands = [[], [], [], []];
      myCards = [];
      trick = [];
      trickWinners = [];
      discardPile = [...burned];
      playedPile = [];
      burnedCards = [...burned];
      showBurned = amount > 0;
      dealProgress = 0;
      busy = true;
      started = false;
      phase = amount > 0 ? 'queimadas' : 'distribuindo';
      status = amount > 0
          ? 'Foram queimadas $amount cartas.'
          : 'Sem queima. Distribuindo as cartas...';
    });

    if (amount > 0) {
      // Mostra as cartas queimadas no centro por alguns instantes.
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      setState(() {
        showBurned = false;
        burnedCards = [];
        phase = 'distribuindo';
        status = 'Cartas queimadas recolhidas. Distribuindo...';
      });
    }

    // Distribui uma carta por vez para cada jogador.
    for (int round = 0; round < 3; round++) {
      for (int player = 0; player < 4; player++) {
        if (!mounted) return;
        final card = deck.removeAt(0);

        setState(() {
          hands[player].add(card);
          if (player == 0) myCards = List.from(hands[0]);
          dealProgress++;
          status = 'Distribuindo cartas: $dealProgress de 12.';
        });

        await Future.delayed(const Duration(milliseconds: 180));
      }
    }

    if (!mounted) return;
    setState(() {
      myCards = List.from(hands[0]);
      currentPlayer = 0;
      started = true;
      busy = false;
      phase = 'finalizado';
      status = 'Cartas distribuídas! Sua vez de jogar.';
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
      if (player == 0) myCards = List.from(hands[0]);
      trick.add(CardPlay(card, player));
      discardPile.add(card);
      playedPile.add(card);
      status = '${players[player]} jogou ${card.label}.';
    });

    if (trick.length == 4) {
      finishTrick();
    } else {
      currentPlayer = (player + 1) % 4;
      if (currentPlayer != 0) {
        scheduleBot();
      } else {
        setState(() => status = 'Sua vez de jogar.');
      }
    }
  }

  void scheduleBot() {
    if (!started || currentPlayer == 0) return;

    busy = true;
    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted || !started || currentPlayer == 0) {
        if (mounted) setState(() => busy = false);
        return;
      }

      final player = currentPlayer;
      final cards = hands[player];
      if (cards.isEmpty) {
        setState(() => busy = false);
        return;
      }

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

      setState(() => busy = false);
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
    setState(() => status = '${players[winner]} venceu esta rodada!');

    final team0Wins = trickWinners.where((p) => p % 2 == 0).length;
    final team1Wins = trickWinners.where((p) => p % 2 == 1).length;

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
      if (currentPlayer != 0) scheduleBot();
    });
  }

  void finishHand() {
    final team0Wins = trickWinners.where((p) => p % 2 == 0).length;
    final team1Wins = trickWinners.where((p) => p % 2 == 1).length;

    int winner;
    if (team0Wins > team1Wins) {
      winner = 0;
    } else if (team1Wins > team0Wins) {
      winner = 1;
    } else {
      winner = trickWinners.isEmpty ? 0 : trickWinners.first % 2;
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

    const nextValues = [2, 4, 6, 10, 12];
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
          started = false;
          busy = false;
        }
      });

      if (!accepted) checkMatch();
    });
  }

  CardPlay? playAt(int player) {
    for (final play in trick) {
      if (play.player == player) return play;
    }
    return null;
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
        toolbarHeight: 44,
        title: const Text(
          'TRUCO ZAP',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xff0b241c),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                children: [
                  salaCompacta(),
                  const SizedBox(height: 5),
                  placarSection(),
                  const SizedBox(height: 5),
                  Expanded(
                    flex: 5,
                    child: mesaSection(),
                  ),
                  const SizedBox(height: 5),
                  statusCompacto(),
                  const SizedBox(height: 5),
                  if (isPreparing || phase == 'distribuindo')
                    preparationSection(),
                  if (myCards.isNotEmpty || started) ...[
                    const SizedBox(height: 5),
                    minhasCartasSection(),
                  ],
                  if (started) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: FilledButton(
                        onPressed: busy ? null : requestTruco,
                        child: const Text('PEDIR TRUCO'),
                      ),
                    ),
                  ],
                  if (!started &&
                      phase != 'embaralhar' &&
                      phase != 'cortar' &&
                      phase != 'queimar' &&
                      phase != 'distribuindo' &&
                      phase != 'queimadas') ...[
                    const SizedBox(height: 5),
                    botoesSection(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get isPreparing =>
      phase == 'embaralhar' || phase == 'cortar' || phase == 'queimar';

  Widget salaCompacta() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: roomController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                labelText: 'Código da sala',
                labelStyle:
                    const TextStyle(color: Colors.white70, fontSize: 11),
                filled: true,
                fillColor: const Color(0xff1d6847),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          height: 38,
          child: FilledButton(
            onPressed: createRoom,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Criar', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          height: 38,
          child: OutlinedButton(
            onPressed: joinRoom,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              side: const BorderSide(color: Colors.white54),
            ),
            child: const Text('Entrar', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget mesaSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xff17613e),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            'MESA — 4 JOGADORES',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      seatCompact(2, 'Sua dupla'),
                      playedCard(2),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 82,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child: seatCompact(1, 'Adversário')),
                            playedCard(1),
                          ],
                        ),
                      ),
                      Expanded(child: centerPile()),
                      SizedBox(
                        width: 82,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            playedCard(3),
                            Flexible(child: seatCompact(3, 'Adversário')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      playedCard(0),
                      seatCompact(0, 'Você'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget seatCompact(int player, String role) {
    final isTurn = started && currentPlayer == player;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor:
              isTurn ? const Color(0xffffd66b) : const Color(0xffd7e8d9),
          child: Icon(
            Icons.person,
            size: 19,
            color: const Color(0xff16452f),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          players[player],
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        Text(
          role,
          maxLines: 1,
          style: const TextStyle(color: Colors.white60, fontSize: 8),
        ),
      ],
    );
  }

  Widget playedCard(int player) {
    final play = playAt(player);
    if (play == null) return const SizedBox(height: 42);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: cardWidget(play.card, small: true),
    );
  }

  Widget centerPile() {
    final lastCards = playedPile
        .skip(max(0, playedPile.length - 3))
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff0d4a32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            showBurned ? 'CARTAS QUEIMADAS' : 'MONTE',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showBurned)
            Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 3),
              child: Text(
                'Foram queimadas ${burnedCards.length} '
                '${burnedCards.length == 1 ? 'carta' : 'cartas'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: showBurned
                  ? SingleChildScrollView(
                      key: ValueKey('burn-${burnedCards.length}'),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        runSpacing: 3,
                        children: burnedCards
                            .map((card) => cardWidget(card, small: true))
                            .toList(),
                      ),
                    )
                  : lastCards.isEmpty
                      ? const Center(
                          key: ValueKey('empty-pile'),
                          child: Text(
                            'Cartas jogadas\naparecem aqui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                            ),
                          ),
                        )
                      : Wrap(
                          key: ValueKey('pile-${discardPile.length}'),
                          alignment: WrapAlignment.center,
                          spacing: 2,
                          children: lastCards
                              .map((card) => cardWidget(card, small: true))
                              .toList(),
                        ),
            ),
          ),
          Text(
            'Descarte: ${discardPile.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget placarSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PARTIDA $matchNumber DE 3   •   $matchWins0 x $matchWins1',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Sua dupla: $pointsTeam0   x   Adversários: $pointsTeam1',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget statusCompacto() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget botoesSection() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: FilledButton.tonal(
              onPressed: fillBots,
              child: const Text(
                'Completar com bots',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: roomReady ? startPreparation : null,
              child: const Text(
                'Iniciar preparação',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget preparationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff1d6847),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            phase == 'embaralhar'
                ? 'PÉ — EMBARALHAMENTO'
                : phase == 'cortar'
                    ? 'ANTEPÉ — CORTE'
                    : phase == 'queimar'
                        ? 'MÃO — QUEIMAR CARTAS'
                        : 'DISTRIBUINDO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isPreparing)
            Text(
              '$countdown s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (phase == 'distribuindo') ...[
            Text(
              '$dealProgress de 12 cartas',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: dealProgress / 12,
              minHeight: 5,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ],
          if (phase == 'embaralhar')
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: shuffleOptions.map((option) {
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(option, style: const TextStyle(fontSize: 10)),
                  selected: selectedShuffle == option,
                  onSelected: (_) => chooseShuffle(option),
                );
              }).toList(),
            ),
          if (phase == 'cortar')
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                ...cutOptions,
                'Não cortar',
              ].map((option) {
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(option, style: const TextStyle(fontSize: 10)),
                  selected: selectedCut == option,
                  onSelected: (_) => chooseCut(option),
                );
              }).toList(),
            ),
          if (phase == 'queimar')
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 1,
              children: List.generate(10, (n) {
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('$n', style: const TextStyle(fontSize: 10)),
                  selected: burnCount == n,
                  onSelected: (_) => chooseBurn(n),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget minhasCartasSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SUAS CARTAS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        if (myCards.isEmpty)
          const Text(
            'Aguardando suas cartas...',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              myCards.length,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => playCard(i),
                  child: cardWidget(myCards[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget cardWidget(PlayingCard card, {bool small = false}) {
    final red = card.suit == '♥' || card.suit == '♦';

    return Container(
      width: small ? 34 : 58,
      height: small ? 46 : 78,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xfffffdf4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 3,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.label,
          style: TextStyle(
            fontSize: small ? 15 : 22,
            fontWeight: FontWeight.bold,
            color: red ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
