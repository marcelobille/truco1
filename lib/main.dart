
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const TrucoApp());

class TrucoApp extends StatelessWidget {
  const TrucoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Truco Mineiro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const TablePage(),
    );
  }
}

class PlayingCard {
  final String rank;
  final String suit;

  const PlayingCard(this.rank, this.suit);

  @override
  String toString() => '$rank$suit';
}

class CardPlay {
  final int player;
  final PlayingCard card;

  CardPlay(this.player, this.card);
}

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage>
    with SingleTickerProviderStateMixin {
  final Random random = Random();

  final List<String> players = [
    'Você',
    'Bot 2',
    'Seu Parceiro',
    'Bot 3',
  ];

  final List<String> ranks = [
    '4', '5', '6', '7', 'Q',
    'J', 'K', 'A', '2', '3',
  ];

  final List<String> suits = ['♣', '♥', '♠', '♦'];

  final List<List<PlayingCard>> hands = [
    [], [], [], [],
  ];

  final List<int> turnOrder = [0, 1, 2, 3];

  List<PlayingCard> deck = [];
  List<CardPlay> playedPile = [];
  List<PlayingCard> burnedCards = [];
  List<int> trickWinners = [];

  int currentPlayer = 0;
  int scoreTeam = 0;
  int scoreBots = 0;
  int trick = 0;

  // Valor atualmente aceito e valor que está sendo proposto.
  int handValue = 2;
  int proposedValue = 0;

  // 0 = sua dupla; 1 = dupla dos bots.
  int raisingTeam = 0;
  int requestingTeam = -1;
  int respondingTeam = -1;

  int dealerPosition = 0;
  int countdown = 5;
  int burnAmount = 0;
  int opponentCountdown = 3;

  int matchWinsTeam = 0;
  int matchWinsBots = 0;

  bool gameStarted = false;
  bool preparing = false;
  bool showBurned = false;
  bool waitingAfterPlay = false;
  bool handFinished = false;

  bool waitingTrucoResponse = false;
  bool checkingOpponents = false;

  String message = '';
  String preparationStep = '';
  String preparationMessage = '';

  String shuffleType = 'Aleatório';
  String cutType = 'Simples';

  Timer? timer;
  Timer? botTimer;
  Timer? playDelayTimer;
  Timer? nextHandTimer;
  Timer? trucoTimer;

  late AnimationController animationController;

  int get dealerPlayer => turnOrder[dealerPosition];
  int get antepePlayer => turnOrder[(dealerPosition + 3) % 4];
  int get handPlayer => turnOrder[(dealerPosition + 1) % 4];

  int get shufflePlayer => dealerPlayer;
  int get cutPlayer => antepePlayer;
  int get burnPlayer => handPlayer;

  int get preparationPlayer {
    switch (preparationStep) {
      case 'embaralhar':
        return shufflePlayer;
      case 'cortar':
        return cutPlayer;
      case 'queimar':
        return burnPlayer;
      default:
        return -1;
    }
  }

  int get leftOpponent => 3;
  int get rightOpponent => 1;

  bool get showMonte {
    return gameStarted ||
        (preparing && preparationStep != 'embaralhar');
  }

  static const List<int> betValues = [2, 4, 6, 9, 12];

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  int teamOf(int player) {
    return player == 0 || player == 2 ? 0 : 1;
  }

  int nextBetValue(int value) {
    final index = betValues.indexOf(value);
    if (index < 0 || index >= betValues.length - 1) {
      return 12;
    }
    return betValues[index + 1];
  }

  int nextPlayer(int player) {
    final index = turnOrder.indexOf(player);
    return turnOrder[(index + 1) % 4];
  }

  String roleOf(int player) {
    if (player == dealerPlayer) return 'PÉ';
    if (player == antepePlayer) return 'ANTEPÉ';
    if (player == handPlayer) return 'MÃO';
    return '';
  }

  String avatarOf(int player) {
    return player == 0 ? '🧑‍🎮' : '🤖';
  }

  String preparationText(String step) {
    final player = step == 'embaralhar'
        ? shufflePlayer
        : step == 'cortar'
            ? cutPlayer
            : burnPlayer;

    if (player == 0) {
      if (step == 'embaralhar') {
        return 'Você é o PÉ: escolha como embaralhar';
      }
      if (step == 'cortar') {
        return 'Você é o ANTEPÉ: escolha como cortar';
      }
      return 'Você é a MÃO: escolha quantas cartas queimar';
    }

    if (step == 'embaralhar') {
      return '${players[player]} está embaralhando';
    }
    if (step == 'cortar') {
      return '${players[player]} está cortando';
    }
    return '${players[player]} está escolhendo quantas cartas queimar';
  }

  List<PlayingCard> makeDeck() {
    final cards = <PlayingCard>[];

    for (final suit in suits) {
      for (final rank in ranks) {
        cards.add(PlayingCard(rank, suit));
      }
    }

    return cards;
  }

  void startPreparation() {
    timer?.cancel();
    botTimer?.cancel();
    playDelayTimer?.cancel();
    trucoTimer?.cancel();

    setState(() {
      preparing = true;
      gameStarted = false;
      handFinished = false;
      waitingAfterPlay = false;
      waitingTrucoResponse = false;
      checkingOpponents = false;
      showBurned = false;

      preparationStep = 'embaralhar';
      preparationMessage = preparationText('embaralhar');

      countdown = 5;
      burnAmount = 0;

      shuffleType = 'Aleatório';
      cutType = 'Simples';

      message = 'Preparando a próxima mão...';

      playedPile.clear();
      burnedCards.clear();
      trickWinners.clear();

      for (final hand in hands) {
        hand.clear();
      }

      trick = 0;
      handValue = 2;
      proposedValue = 0;
      raisingTeam = 0;
      requestingTeam = -1;
      respondingTeam = -1;
    });

    startCountdown();
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

        if (countdown > 1) {
          setState(() {
            countdown--;
          });
        } else {
          t.cancel();

          setState(() {
            countdown = 0;
          });

          advancePreparation();
        }
      },
    );
  }

  void advancePreparation() {
    if (!preparing) return;

    if (preparationPlayer != 0) {
      if (preparationStep == 'embaralhar') {
        shuffleType = [
          'Por cima',
          'Por baixo',
          'Intercalado',
          'Aleatório',
        ][random.nextInt(4)];
      } else if (preparationStep == 'cortar') {
        cutType = [
          'Simples',
          'Duplo',
          'Aleatório',
          'Não cortar',
        ][random.nextInt(4)];
      } else if (preparationStep == 'queimar') {
        burnAmount = random.nextInt(10);
      }
    }

    if (preparationStep == 'embaralhar') {
      setState(() {
        preparationStep = 'cortar';
        preparationMessage = preparationText('cortar');
        countdown = 5;
      });
      startCountdown();
      return;
    }

    if (preparationStep == 'cortar') {
      setState(() {
        preparationStep = 'queimar';
        preparationMessage = preparationText('queimar');
        countdown = 5;
      });
      startCountdown();
      return;
    }

    distributeCards();
  }

  void chooseShuffle(String type) {
    if (!preparing ||
        preparationStep != 'embaralhar' ||
        shufflePlayer != 0) {
      return;
    }

    timer?.cancel();

    setState(() {
      shuffleType = type;
      preparationStep = 'cortar';
      preparationMessage = preparationText('cortar');
      countdown = 5;
    });

    startCountdown();
  }

  void chooseCut(String type) {
    if (!preparing ||
        preparationStep != 'cortar' ||
        cutPlayer != 0) {
      return;
    }

    timer?.cancel();

    setState(() {
      cutType = type;
      preparationStep = 'queimar';
      preparationMessage = preparationText('queimar');
      countdown = 5;
    });

    startCountdown();
  }

  void chooseBurn(int amount) {
    if (!preparing ||
        preparationStep != 'queimar' ||
        burnPlayer != 0) {
      return;
    }

    timer?.cancel();

    setState(() {
      burnAmount = amount.clamp(0, 9);
    });

    distributeCards();
  }

  Future<void> distributeCards() async {
    timer?.cancel();

    deck = makeDeck();
    shuffleDeck();

    if (cutType != 'Não cortar') {
      cutDeck();
    }

    final safeBurn = burnAmount.clamp(0, 9);

    burnedCards = deck.take(safeBurn).toList();
    deck = deck.skip(safeBurn).toList();

    setState(() {
      showBurned = true;
      preparationMessage = 'Cartas queimadas';

      message = safeBurn == 0
          ? 'Nenhuma carta foi queimada'
          : 'Foram queimadas $safeBurn cartas';
    });

    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    setState(() {
      showBurned = false;

      for (final hand in hands) {
        hand.clear();
      }

      for (int rodada = 0; rodada < 3; rodada++) {
        for (int player = 0; player < 4; player++) {
          if (deck.isNotEmpty) {
            hands[player].add(deck.removeAt(0));
          }
        }
      }

      playedPile.clear();
      trickWinners.clear();

      trick = 0;
      handValue = 2;
      proposedValue = 0;
      raisingTeam = 0;
      waitingAfterPlay = false;
      waitingTrucoResponse = false;
      checkingOpponents = false;

      currentPlayer = handPlayer;

      preparing = false;
      gameStarted = true;

      message = currentPlayer == 0
          ? 'Sua vez de jogar!'
          : '${players[currentPlayer]} vai jogar';
    });

    if (currentPlayer != 0) {
      scheduleBot();
    }
  }

  void shuffleDeck() {
    if (shuffleType == 'Aleatório') {
      deck.shuffle(random);
      return;
    }

    final original = List<PlayingCard>.from(deck);

    if (shuffleType == 'Por cima') {
      deck = original.reversed.toList();
    } else if (shuffleType == 'Por baixo') {
      deck = [...original];
    } else if (shuffleType == 'Intercalado') {
      final middle = original.length ~/ 2;
      final first = original.sublist(0, middle);
      final second = original.sublist(middle);
      final result = <PlayingCard>[];

      for (int i = 0; i < middle; i++) {
        result.add(second[i]);
        result.add(first[i]);
      }

      if (second.length > first.length) {
        result.add(second.last);
      }

      deck = result;
    }
  }

  void cutDeck() {
    if (deck.isEmpty) return;

    int cutPosition;

    if (cutType == 'Simples') {
      cutPosition = deck.length ~/ 2;
    } else if (cutType == 'Duplo') {
      cutPosition = deck.length ~/ 3;
    } else {
      cutPosition = random.nextInt(deck.length);
    }

    if (cutPosition <= 0 || cutPosition >= deck.length) {
      return;
    }

    final first = deck.sublist(0, cutPosition);
    final second = deck.sublist(cutPosition);

    deck = [...second, ...first];

    if (cutType == 'Duplo') {
      final middle = deck.length ~/ 2;
      deck = [
        ...deck.sublist(middle),
        ...deck.sublist(0, middle),
      ];
    }
  }

  int cardPower(PlayingCard card) {
    if (card.rank == '4' && card.suit == '♣') return 100;
    if (card.rank == '7' && card.suit == '♥') return 99;
    if (card.rank == 'A' && card.suit == '♠') return 98;
    if (card.rank == '7' && card.suit == '♦') return 97;

    switch (card.rank) {
      case '3':
        return 90;
      case '2':
        return 80;
      case 'A':
        return 70;
      case 'K':
        return 60;
      case 'J':
        return 50;
      case 'Q':
        return 40;
      case '7':
        return 30;
      case '6':
        return 20;
      case '5':
        return 10;
      case '4':
        return 5;
      default:
        return 0;
    }
  }

  void playAt(int index) {
    if (!gameStarted ||
        preparing ||
        waitingAfterPlay ||
        waitingTrucoResponse ||
        checkingOpponents ||
        currentPlayer != 0) {
      return;
    }

    if (index < 0 || index >= hands[0].length) return;

    playCard(0, hands[0][index]);
  }

  void playCard(int player, PlayingCard card) {
    if (!gameStarted ||
        preparing ||
        waitingAfterPlay ||
        waitingTrucoResponse ||
        checkingOpponents ||
        player != currentPlayer ||
        !hands[player].contains(card)) {
      return;
    }

    setState(() {
      waitingAfterPlay = true;

      hands[player].remove(card);
      playedPile.add(CardPlay(player, card));

      message = '${players[player]} jogou $card';
      currentPlayer = nextPlayer(player);
    });

    playDelayTimer?.cancel();

    playDelayTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted || !gameStarted) return;

        if (playedPile.length == 4) {
          setState(() {
            waitingAfterPlay = false;
          });

          finishTrick();
          return;
        }

        setState(() {
          waitingAfterPlay = false;

          message = currentPlayer == 0
              ? 'Sua vez de jogar!'
              : '${players[currentPlayer]} vai jogar';
        });

        if (currentPlayer != 0) {
          scheduleBot();
        }
      },
    );
  }

  void playForPlayer(int player) {
    if (!gameStarted ||
        waitingAfterPlay ||
        waitingTrucoResponse ||
        checkingOpponents ||
        hands[player].isEmpty) {
      return;
    }

    // Os bots adversários podem pedir aumento automaticamente.
    if (teamOf(player) == 1 &&
        raisingTeam == 1 &&
        proposedValue == 0 &&
        random.nextInt(100) < 22) {
      botRequestTruco();
      return;
    }

    final cards = List<PlayingCard>.from(hands[player]);

    cards.sort(
      (a, b) => cardPower(a).compareTo(cardPower(b)),
    );

    playCard(player, cards.first);
  }

  void scheduleBot() {
    botTimer?.cancel();

    botTimer = Timer(
      const Duration(milliseconds: 850),
      () {
        if (!mounted ||
            !gameStarted ||
            preparing ||
            waitingAfterPlay ||
            waitingTrucoResponse ||
            checkingOpponents) {
          return;
        }

        if (currentPlayer != 0) {
          playForPlayer(currentPlayer);
        }
      },
    );
  }

  void finishTrick() {
    botTimer?.cancel();

    final plays = List<CardPlay>.from(playedPile);
    if (plays.length != 4) return;

    int highestPower = -1;

    for (final play in plays) {
      highestPower = max(
        highestPower,
        cardPower(play.card),
      );
    }

    final strongest = plays
        .where((play) => cardPower(play.card) == highestPower)
        .toList();

    final strongestTeams = strongest
        .map((play) => teamOf(play.player))
        .toSet();

    final winnerTeam = strongestTeams.length == 1
        ? strongestTeams.first
        : -1;

    final winnerPlayer = strongest.first.player;

    trickWinners.add(winnerTeam);

    setState(() {
      if (winnerTeam == -1) {
        message = 'Rodada empatada!';
      } else if (winnerTeam == 0) {
        message = 'Você e seu parceiro ganharam a rodada!';
      } else {
        message = 'Os bots ganharam a rodada!';
      }

      trick++;
      playedPile.clear();
    });

    final decision = handDecisionAfterSecondRound();

    if (decision != null) {
      finishHand(decision);
      return;
    }

    if (trick >= 3 || hands.every((hand) => hand.isEmpty)) {
      finishHand();
      return;
    }

    setState(() {
      currentPlayer = winnerTeam == -1
          ? handPlayer
          : winnerPlayer;

      waitingAfterPlay = false;

      message = currentPlayer == 0
          ? 'Sua vez de jogar!'
          : '${players[currentPlayer]} vai jogar';
    });

    if (currentPlayer != 0) {
      scheduleBot();
    }
  }

  int? handDecisionAfterSecondRound() {
    if (trickWinners.length < 2) return null;

    final first = trickWinners[0];
    final second = trickWinners[1];

    if (first != -1 && first == second) {
      return first;
    }

    if (first == -1 && second != -1) {
      return second;
    }

    if (first != -1 && second == -1) {
      return first;
    }

    return null;
  }

  void finishHand([int? forcedWinner]) {
    if (handFinished) return;

    handFinished = true;
    waitingAfterPlay = false;
    waitingTrucoResponse = false;
    checkingOpponents = false;

    botTimer?.cancel();
    playDelayTimer?.cancel();
    trucoTimer?.cancel();

    int? winner = forcedWinner;

    if (winner == null && trickWinners.length >= 3) {
      final third = trickWinners[2];
      if (third != -1) winner = third;
    } else if (winner == null && trickWinners.length == 1) {
      if (trickWinners[0] != -1) {
        winner = trickWinners[0];
      }
    }

    setState(() {
      if (winner == 0) {
        scoreTeam += handValue;
        message = 'Você e seu parceiro ganharam a mão! $handValue pontos.';
      } else if (winner == 1) {
        scoreBots += handValue;
        message = 'Os bots ganharam a mão! $handValue pontos.';
      } else {
        message = 'Mão empatada!';
      }
    });

    checkMatch();
  }

  void checkMatch() {
    if (scoreTeam >= 12) {
      matchWinsTeam++;

      setState(() {
        message = 'Você e seu parceiro venceram a partida!';
      });

      resetMatch();
      return;
    }

    if (scoreBots >= 12) {
      matchWinsBots++;

      setState(() {
        message = 'Os bots venceram a partida!';
      });

      resetMatch();
      return;
    }

    dealerPosition = (dealerPosition + 1) % 4;

    nextHandTimer?.cancel();

    nextHandTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (mounted) startPreparation();
      },
    );
  }

  void resetMatch() {
    nextHandTimer?.cancel();

    nextHandTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          scoreTeam = 0;
          scoreBots = 0;
          trick = 0;
          handValue = 2;
          proposedValue = 0;
          raisingTeam = 0;
          requestingTeam = -1;
          respondingTeam = -1;
          dealerPosition = 0;

          gameStarted = false;
          preparing = false;
          waitingAfterPlay = false;
          waitingTrucoResponse = false;
          checkingOpponents = false;
          handFinished = false;

          playedPile.clear();
          burnedCards.clear();
          trickWinners.clear();

          for (final hand in hands) {
            hand.clear();
          }
        });
      },
    );
  }

  // Inicia um pedido de aumento feito por uma das duplas.
  void beginTrucoRequest(int team) {
    if (!gameStarted ||
        handFinished ||
        waitingAfterPlay ||
        waitingTrucoResponse ||
        checkingOpponents ||
        team != raisingTeam ||
        handValue >= 12) {
      return;
    }

    final target = nextBetValue(handValue);

    setState(() {
      proposedValue = target;
      requestingTeam = team;
      respondingTeam = 1 - team;
      waitingTrucoResponse = true;
      checkingOpponents = true;
      opponentCountdown = 3;

      message = team == 0
          ? 'Sua dupla pediu $target!'
          : 'Os bots pediram $target!';
    });

    trucoTimer?.cancel();

    trucoTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted || !gameStarted || handFinished) {
          t.cancel();
          return;
        }

        if (opponentCountdown > 1) {
          setState(() {
            opponentCountdown--;
          });
          return;
        }

        t.cancel();

        if (respondingTeam == 1) {
          botAnswerTruco();
        } else {
          setState(() {
            checkingOpponents = false;
            opponentCountdown = 0;
            message = 'Os bots pediram $proposedValue! Sua decisão.';
          });
        }
      },
    );
  }

  void requestTruco() {
    if (currentPlayer != 0 ||
        raisingTeam != 0 ||
        !gameStarted ||
        waitingAfterPlay) {
      return;
    }

    beginTrucoRequest(0);
  }

  void botRequestTruco() {
    if (raisingTeam != 1 ||
        currentPlayer == 0 ||
        !gameStarted) {
      return;
    }

    beginTrucoRequest(1);
  }

  // Os bots escolhem automaticamente aceitar, aumentar ou correr.
  void botAnswerTruco() {
    if (!waitingTrucoResponse ||
        respondingTeam != 1 ||
        !gameStarted) {
      return;
    }

    final canRaise = proposedValue < 12;
    final choice = random.nextInt(100);

    if (choice < 68) {
      acceptTruco();
    } else if (choice < 84 && canRaise) {
      raiseTruco();
    } else {
      runFromTruco();
    }
  }

  void acceptTruco() {
    if (!waitingTrucoResponse || handFinished) return;

    setState(() {
      handValue = proposedValue;
      proposedValue = 0;

      // Depois que uma dupla aceita, a outra passa a poder aumentar.
      raisingTeam = respondingTeam;

      waitingTrucoResponse = false;
      checkingOpponents = false;
      requestingTeam = -1;
      respondingTeam = -1;

      message = 'Truco aceito! Agora vale $handValue pontos.';
    });

    if (currentPlayer != 0) {
      scheduleBot();
    }
  }

  void raiseTruco() {
    if (!waitingTrucoResponse ||
        handFinished ||
        proposedValue >= 12) {
      return;
    }

    // Quem está respondendo passa a ser o novo solicitante.
    final newRequester = respondingTeam;
    final newValue = nextBetValue(proposedValue);

    setState(() {
      handValue = proposedValue;
      proposedValue = newValue;

      requestingTeam = newRequester;
      respondingTeam = 1 - newRequester;

      waitingTrucoResponse = true;
      checkingOpponents = true;
      opponentCountdown = 3;

      message = newRequester == 0
          ? 'Você pediu $newValue!'
          : 'Os bots pediram $newValue!';
    });

    trucoTimer?.cancel();

    trucoTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted || !gameStarted || handFinished) {
          t.cancel();
          return;
        }

        if (opponentCountdown > 1) {
          setState(() {
            opponentCountdown--;
          });
          return;
        }

        t.cancel();

        if (respondingTeam == 1) {
          botAnswerTruco();
        } else {
          setState(() {
            checkingOpponents = false;
            opponentCountdown = 0;
            message = 'Os bots pediram $proposedValue! Sua decisão.';
          });
        }
      },
    );
  }

  void runFromTruco() {
    if (!waitingTrucoResponse || handFinished) return;

    final winner = requestingTeam;
    final points = handValue;

    trucoTimer?.cancel();
    botTimer?.cancel();
    playDelayTimer?.cancel();

    setState(() {
      if (winner == 0) {
        scoreTeam += points;
        message = 'Os bots correram! Sua dupla ganhou $points pontos.';
      } else {
        scoreBots += points;
        message = 'Você correu! Os bots ganharam $points pontos.';
      }

      proposedValue = 0;
      waitingTrucoResponse = false;
      checkingOpponents = false;
      handFinished = true;
      gameStarted = false;
    });

    checkMatch();
  }

  Widget optionButton(
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    botTimer?.cancel();
    playDelayTimer?.cancel();
    nextHandTimer?.cancel();
    trucoTimer?.cancel();

    animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF123D2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF082719),
        title: const Text(
          'TRUCO MINEIRO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            placarSection(),
            const SizedBox(height: 8),
            Expanded(child: mesaSection()),
            painelSection(),
          ],
        ),
      ),
    );
  }

  Widget placarSection() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF082719),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'VOCÊ + PARCEIRO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                '$scoreTeam',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Text(
            'X',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Column(
            children: [
              const Text(
                'BOTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                '$scoreBots',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget mesaSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF17633C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFB68B45),
          width: 4,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: jogadorSection(2),
          ),
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(child: jogadorSection(3)),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(child: jogadorSection(1)),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: jogadorSection(0),
          ),
          Positioned(
            top: 105,
            left: 0,
            right: 0,
            child: Center(child: playedCardWidget(2)),
          ),
          Positioned(
            left: 48,
            top: 0,
            bottom: 0,
            child: Center(child: playedCardWidget(3)),
          ),
          Positioned(
            right: 48,
            top: 0,
            bottom: 0,
            child: Center(child: playedCardWidget(1)),
          ),
          Positioned(
            bottom: 105,
            left: 0,
            right: 0,
            child: Center(child: playedCardWidget(0)),
          ),
          if (showMonte)
            Positioned(
              top: 165,
              left: 0,
              right: 0,
              child: Center(child: monteWidget()),
            ),
          Center(child: centerPile()),
        ],
      ),
    );
  }

  Widget monteWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.12,
              child: cartaVerso(),
            ),
            Transform.rotate(
              angle: 0.08,
              child: cartaVerso(),
            ),
            cartaVerso(),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF082719),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'MONTE',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget cartaVerso() {
    return Container(
      width: 27,
      height: 39,
      decoration: BoxDecoration(
        color: const Color(0xFF183A83),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
      ),
      child: const Center(
        child: Text(
          '★',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget jogadorSection(int player) {
    final bool isYou = player == 0;
    final role = roleOf(player);
    final int playerTeam = teamOf(player);

    final bool wonLastRound =
        trickWinners.isNotEmpty &&
        trickWinners.last == playerTeam;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF082719),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.amber,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      avatarOf(player),
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                ),
                if (wonLastRound)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: currentPlayer == player
                    ? Colors.amber
                    : const Color(0xFF082719),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                players[player],
                style: TextStyle(
                  color: currentPlayer == player
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        if (role.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              role,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (isYou)
          cartasDoJogador(player)
        else
          cartasDosBots(player),
      ],
    );
  }

  Widget cartasDoJogador(int player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        hands[player].length,
        (index) {
          final card = hands[player][index];
          final red = card.suit == '♥' || card.suit == '♦';

          return GestureDetector(
            onTap: () {
              if (currentPlayer == 0 && !waitingAfterPlay) {
                playAt(index);
              }
            },
            child: Container(
              width: 48,
              height: 70,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.black,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.rank,
                    style: TextStyle(
                      color: red ? Colors.red : Colors.black,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    card.suit,
                    style: TextStyle(
                      color: red ? Colors.red : Colors.black,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget cartasDosBots(int player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        hands[player].length,
        (index) {
          return Container(
            width: 25,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF183A83),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            child: const Center(
              child: Text(
                '★',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget playedCardWidget(int player) {
    final plays = playedPile.where(
      (play) => play.player == player,
    );

    if (plays.isEmpty) {
      return const SizedBox.shrink();
    }

    final card = plays.first.card;
    final red = card.suit == '♥' || card.suit == '♦';

    return Container(
      width: 42,
      height: 59,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.black,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: red ? Colors.red : Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: red ? Colors.red : Colors.black,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget centerPile() {
    if (preparing &&
        (preparationStep == 'embaralhar' ||
            preparationStep == 'cortar')) {
      return preparationAnimation();
    }

    if (showBurned && burnedCards.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF082719),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CARTAS QUEIMADAS',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              'Foram queimadas ${burnedCards.length} cartas',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 3,
              children: burnedCards.map(miniCard).toList(),
            ),
          ],
        ),
      );
    }

    if (showBurned && burnedCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF082719),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'NENHUMA CARTA QUEIMADA',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x66082719),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'MESA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Rodadas: ${trickWinners.length}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 10,
            ),
          ),
          Text(
            'Valendo: $handValue pontos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget preparationAnimation() {
    final isShuffle = preparationStep == 'embaralhar';
    final type = isShuffle ? shuffleType : cutType;

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final t = animationController.value;
        final wave = sin(t * pi);

        double leftX = 0;
        double rightX = 0;
        double leftY = 0;
        double rightY = 0;
        double leftAngle = 0;
        double rightAngle = 0;

        if (isShuffle) {
          switch (type) {
            case 'Por cima':
              leftX = -18 * wave;
              rightX = 18 * wave;
              leftY = -12 * wave;
              rightY = 12 * wave;
              leftAngle = -0.18 * wave;
              rightAngle = 0.18 * wave;
              break;
            case 'Por baixo':
              leftX = -12 * wave;
              rightX = 12 * wave;
              leftY = 13 * wave;
              rightY = -13 * wave;
              leftAngle = 0.12 * wave;
              rightAngle = -0.12 * wave;
              break;
            case 'Intercalado':
              leftX = -22 * wave;
              rightX = 22 * wave;
              leftAngle = 0.22 * wave;
              rightAngle = -0.22 * wave;
              break;
            default:
              leftX = -18 * wave;
              rightX = 18 * wave;
              leftY = 12 * sin(t * pi * 2);
              rightY = -12 * sin(t * pi * 2);
              leftAngle = 0.30 * wave;
              rightAngle = -0.30 * wave;
          }
        } else {
          switch (type) {
            case 'Simples':
              leftX = 15 * wave;
              rightX = -15 * wave;
              leftAngle = 0.15 * wave;
              rightAngle = -0.15 * wave;
              break;
            case 'Duplo':
              leftX = 22 * wave;
              rightX = -22 * wave;
              leftY = 9 * wave;
              rightY = -9 * wave;
              leftAngle = 0.24 * wave;
              rightAngle = -0.24 * wave;
              break;
            case 'Aleatório':
              leftX = 18 * sin(t * pi * 2);
              rightX = -18 * cos(t * pi * 2);
              leftY = 12 * cos(t * pi * 2);
              rightY = -12 * sin(t * pi * 2);
              leftAngle = 0.30 * wave;
              rightAngle = -0.30 * wave;
              break;
            default:
              leftX = 0;
              rightX = 0;
              leftY = 0;
              rightY = 0;
          }
        }

        return Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xE6082719),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isShuffle ? 'EMBARALHANDO' : 'CORTANDO',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 112,
                height: 55,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(leftX, leftY),
                      child: Transform.rotate(
                        angle: leftAngle,
                        child: cartaVerso(),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(rightX, rightY),
                      child: Transform.rotate(
                        angle: rightAngle,
                        child: cartaVerso(),
                      ),
                    ),
                    if (type == 'Duplo' ||
                        type == 'Intercalado' ||
                        type == 'Aleatório')
                      Transform.translate(
                        offset: Offset(0, -wave * 5),
                        child: Transform.rotate(
                          angle: wave * 0.10,
                          child: cartaVerso(),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                type,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget miniCard(PlayingCard card) {
    final red = card.suit == '♥' || card.suit == '♦';

    return Container(
      width: 32,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: red ? Colors.red : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            card.suit,
            style: TextStyle(
              color: red ? Colors.red : Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget painelSection() {
    final canUserRequest = gameStarted &&
        !preparing &&
        !waitingAfterPlay &&
        !waitingTrucoResponse &&
        !checkingOpponents &&
        currentPlayer == 0 &&
        raisingTeam == 0 &&
        handValue < 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFF082719),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (gameStarted)
            Text(
              'MÃO VALENDO $handValue PONTOS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),

          if (checkingOpponents)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF0B241C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                children: [
                  const Text(
                    'Verificando se os oponentes irão aceitar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$opponentCountdown',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (waitingTrucoResponse &&
              !checkingOpponents &&
              respondingTeam == 0)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              children: [
                optionButton(
                  'ACEITAR ${proposedValue == 4 ? 'TRUCO' : proposedValue}',
                  acceptTruco,
                ),
                if (proposedValue < 12)
                  optionButton(
                    'PEDIR ${nextBetValue(proposedValue)}',
                    raiseTruco,
                  ),
                optionButton(
                  'CORRER',
                  runFromTruco,
                ),
              ],
            ),

          if (canUserRequest)
            ElevatedButton(
              onPressed: requestTruco,
              child: Text(
                'PEDIR ${nextBetValue(handValue)}',
              ),
            ),

          if (!gameStarted && !preparing)
            ElevatedButton(
              onPressed: startPreparation,
              child: const Text('INICIAR PARTIDA'),
            ),

          if (preparing)
            Column(
              children: [
                Text(
                  preparationMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$countdown',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (preparationStep == 'embaralhar' &&
                    preparationPlayer == 0)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      optionButton(
                        'Por cima',
                        () => chooseShuffle('Por cima'),
                      ),
                      optionButton(
                        'Por baixo',
                        () => chooseShuffle('Por baixo'),
                      ),
                      optionButton(
                        'Intercalado',
                        () => chooseShuffle('Intercalado'),
                      ),
                      optionButton(
                        'Aleatório',
                        () => chooseShuffle('Aleatório'),
                      ),
                    ],
                  ),

                if (preparationStep == 'cortar' &&
                    preparationPlayer == 0)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      optionButton(
                        'Simples',
                        () => chooseCut('Simples'),
                      ),
                      optionButton(
                        'Duplo',
                        () => chooseCut('Duplo'),
                      ),
                      optionButton(
                        'Aleatório',
                        () => chooseCut('Aleatório'),
                      ),
                      optionButton(
                        'Não cortar',
                        () => chooseCut('Não cortar'),
                      ),
                    ],
                  ),

                if (preparationStep == 'queimar' &&
                    preparationPlayer == 0)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: [
                      optionButton(
                        'Não queimar',
                        () => chooseBurn(0),
                      ),
                      for (int i = 1; i <= 9; i++)
                        optionButton(
                          '$i ${i == 1 ? 'carta' : 'cartas'}',
                          () => chooseBurn(i),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
