import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/components/movie_card.dart';
import 'package:movie_app/main_videoplayer.dart';
import 'package:movie_app/settings_provider.dart';
import 'watch_party_screen.dart';
import 'watch_party_utils.dart';
import 'watch_party_flow.dart';

Widget buildDirectStreamSearchView(BuildContext context,
    WatchPartyScreenState state, TextEditingController searchController) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Select Movie to Stream"),
      backgroundColor: Colors.black87,
      elevation: 0,
      actions: [buildTrialTicketCounter(context, state)],
    ),
    body: Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.black],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: "Search movies",
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: true,
                    fillColor: Colors.black54,
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (value) => searchMovies(value, state),
                ),
              ),
              Expanded(
                child: state.isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Provider.of<SettingsProvider>(context)
                              .accentColor,
                        ),
                      )
                    : state.searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              "Search for a movie",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: state.searchResults.length,
                            itemBuilder: (context, index) {
                              final movie = state.searchResults[index];
                              return MovieCard.fromJson(
                                movie,
                                onTap: () => state.startMoviePlayback(movie),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        if (state.isLoading)
          Center(
            child: CircularProgressIndicator(
              color: Provider.of<SettingsProvider>(context).accentColor,
            ),
          ),
      ],
    ),
  );
}

Widget buildCreatorSetupView(BuildContext context, WatchPartyScreenState state,
    TextEditingController searchController) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Create Watch Party"),
      backgroundColor: Colors.black87,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: state.partyCode != null
              ? () => showPartyCode(context, state)
              : null,
        ),
        buildTrialTicketCounter(context, state),
      ],
    ),
    body: Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.black],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: "Search movies",
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    filled: true,
                    fillColor: Colors.black54,
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (value) => searchMovies(value, state),
                ),
              ),
              Expanded(
                child: state.isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Provider.of<SettingsProvider>(context)
                              .accentColor,
                        ),
                      )
                    : state.searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              "Search for a movie",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: state.searchResults.length,
                            itemBuilder: (context, index) {
                              final movie = state.searchResults[index];
                              return MovieCard.fromJson(
                                movie,
                                onTap: () =>
                                    showScheduleDialog(context, movie, state),
                              );
                            },
                          ),
              ),
              if (state.partyCode != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "Party Code: ${state.partyCode}\nParticipants: ${state.inviteJoinCount}/5",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
        if (state.isLoading)
          Center(
            child: CircularProgressIndicator(
              color: Provider.of<SettingsProvider>(context).accentColor,
            ),
          ),
      ],
    ),
  );
}

Widget buildInviteeWaitingView(
    BuildContext context, WatchPartyScreenState state) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Waiting for Party"),
      backgroundColor: Colors.black87,
      elevation: 0,
      actions: [buildTrialTicketCounter(context, state)],
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Provider.of<SettingsProvider>(context).accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            "Party Code: ${state.partyCode}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const Text(
            "Waiting for host...",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

Widget buildPartyView(BuildContext context, WatchPartyScreenState state) {
  final chatWidth = MediaQuery.of(context).size.width * 0.35;

  return Scaffold(
    body: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                spreadRadius: 5,
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            children: [
              MainVideoPlayer(
                videoPath: state.videoPath,
                title: state.title,
                isHls: state.isHls,
                subtitleUrl: state.subtitleUrl,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 50,
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      10,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child:
                            Icon(Icons.person, color: Colors.white54, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: state.curtainController,
          builder: (context, _) {
            final value = state.curtainController.value;
            return Positioned(
              left: -MediaQuery.of(context).size.width * (1 - value),
              right: -MediaQuery.of(context).size.width * (1 - value),
              top: 0,
              bottom: 0,
              child: Container(
                color: Colors.red[900],
                child: Center(
                  child: Text(
                    state.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: state.doorsController,
          builder: (context, _) {
            final value = state.doorsController.value;
            if (value == 1) {
              return buildPremiumUpsell(context, state);
            }
            return Positioned(
              left: -MediaQuery.of(context).size.width * (1 - value) / 2,
              right: -MediaQuery.of(context).size.width * (1 - value) / 2,
              top: 0,
              bottom: 0,
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.lock, color: Colors.white, size: 100),
                ),
              ),
            );
          },
        ),
        AnimatedOpacity(
          opacity: state.controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: buildControlsOverlay(context, state, chatWidth),
        ),
        if (state.trialTickets == 1 && state.partyStartTime != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[700],
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: const Text(
                "Last trial! Upgrade for unlimited access",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (state.remainingMinutes > 0)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                "Time left: ${state.remainingMinutes} min",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        if (state.secretBypass)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: const Text(
                "ADMIN MODE",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ...state.emojiReactions.map((reaction) => Positioned(
              bottom: reaction['offset'].dy,
              left: MediaQuery.of(context).size.width * 0.5,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(seconds: 2),
                child: Text(
                  reaction['emoji'],
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            )),
      ],
    ),
  );
}

Widget buildControlsOverlay(
    BuildContext context, WatchPartyScreenState state, double chatWidth) {
  return Stack(
    children: [
      Positioned(
        left: 0,
        width: chatWidth,
        height: double.infinity,
        child: buildChatPanel(context, state),
      ),
      Positioned(
        right: 0,
        width: MediaQuery.of(context).size.width * 0.2,
        height: double.infinity,
        child: buildControlPanel(context, state),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: buildReactionBar(context, state),
      ),
    ],
  );
}

Widget buildChatPanel(BuildContext context, WatchPartyScreenState state) {
  return Container(
    color: Colors.black87,
    child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              final message = state.messages[state.messages.length - 1 - index];
              final userId = message.split(':').first;
              final seat = state.userSeats[userId] ?? 'A1';
              final isPremium = state.isPremium;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: isPremium
                        ? Border.all(color: Colors.amber, width: 2)
                        : null,
                  ),
                  child: ListTile(
                    leading: Text(
                      seat,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    title: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    trailing: isPremium
                        ? const Icon(Icons.star, color: Colors.amber, size: 16)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: state.chatController,
                  decoration: const InputDecoration(
                    hintText: "Message from your seat...",
                    hintStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black54,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (value) {
                    state.sendMessage(value);
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: Provider.of<SettingsProvider>(context).accentColor,
                ),
                onPressed: () {
                  state.sendMessage(state.chatController.text);
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildControlPanel(BuildContext context, WatchPartyScreenState state) {
  return Container(
    color: Colors.black87,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          onPressed: () {
            state.playVideo();
            startControlsTimer(state);
          },
        ),
        IconButton(
          icon: const Icon(Icons.pause, color: Colors.white),
          onPressed: () {
            state.pauseVideo();
            startControlsTimer(state);
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: () => startControlsTimer(state),
        ),
        IconButton(
          icon: Icon(
            state.chatMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: state.toggleChatMute,
        ),
        IconButton(
          icon: Icon(
            state.cinemaSoundEnabled ? Icons.music_note : Icons.music_off,
            color: Colors.white,
          ),
          onPressed: state.toggleCinemaSound,
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () => showPartyCode(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.fastfood, color: Colors.white),
          onPressed: () {
            state.addEmojiReaction("🍿");
            showSuccess(context, "Popcorn popped for everyone!");
          },
          tooltip: "Virtual Concessions",
        ),
        if (state.isDirectStreamMode)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: state.resetStream,
            tooltip: "Search for another movie",
          ),
      ],
    ),
  );
}

Widget buildReactionBar(BuildContext context, WatchPartyScreenState state) {
  return Container(
    color: Colors.black54,
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ["👍", "❤️", "😂", "😮", "😢", "👏"].map((emoji) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: () => state.addEmojiReaction(emoji),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24, color: Colors.amber),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Widget buildTrialTicketCounter(
    BuildContext context, WatchPartyScreenState state) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_activity, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(
            "Tickets left: ${state.trialTickets}/3",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

Widget buildPremiumUpsell(BuildContext context, WatchPartyScreenState state) {
  return Container(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Buy Premium for Unlimited Access!",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 10, color: Colors.black)],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onPressed: state.upgradeToPremium,
            child: const Text(
              "Unlock Cinema VIP",
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                showSuccess(context, "Watch a sponsored ad for a free trial!"),
            child: const Text(
              "Watch Ad for Free Trial",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class PopcornProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;

  const PopcornProgressBar(
      {super.key, required this.position, required this.duration});

  @override
  Widget build(BuildContext context) {
    final progress = position.inMilliseconds / duration.inMilliseconds;
    const kernels = 10;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kernels, (index) {
        final isLit = index / kernels <= progress;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.local_dining,
            color: isLit ? Colors.amber : Colors.white54,
            size: 20,
          ),
        );
      }),
    );
  }
}
