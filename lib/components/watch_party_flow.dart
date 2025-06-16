import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:movie_app/settings_provider.dart';
import 'watch_party_screen.dart';
import 'watch_party_utils.dart';

void showRoleSelection(BuildContext context, WatchPartyScreenState state) {
  if (state.isAuthorized) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Welcome to Cinema Watch Party"),
      content: const Text("Select your role:"),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      backgroundColor: Colors.black87,
      actions: [
        TextButton(
          onPressed: () => handleInviteeFlow(dialogContext, state),
          child:
              const Text("Join Party", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Provider.of<SettingsProvider>(context, listen: false)
                    .accentColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () => handleCreatorFlow(dialogContext, state),
          child:
              const Text("Create Party", style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () => handleAdminFlow(dialogContext, state),
          child:
              const Text("Admin Access", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void handleInviteeFlow(BuildContext context, WatchPartyScreenState state) {
  Navigator.pop(context);
  showCodeEntryDialog(context, state);
}

void handleCreatorFlow(BuildContext context, WatchPartyScreenState state) {
  state.authorizeCreator();
  Navigator.pop(context);
  showPartyCode(context, state);
}

void handleAdminFlow(BuildContext context, WatchPartyScreenState state) {
  Navigator.pop(context);
  showAdminAuthDialog(context, state);
}

void showAdminAuthDialog(BuildContext context, WatchPartyScreenState state) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Admin Authentication"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: "Enter admin code"),
        obscureText: true,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      backgroundColor: Colors.black87,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Provider.of<SettingsProvider>(context, listen: false)
                    .accentColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () {
            final input = controller.text;
            if (input == "ADMIN2025") {
              state.authorizeAdmin();
              Navigator.pop(dialogContext);
              showSuccess(context, "Admin access granted");
            } else if (input == "STREAMNOW") {
              state.authorizeDirectStream();
              Navigator.pop(dialogContext);
              showSuccess(context, "Direct streaming mode activated");
            } else {
              showError(context, "Invalid admin code");
            }
            controller.dispose();
          },
          child: const Text("Verify", style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

void showCodeEntryDialog(BuildContext context, WatchPartyScreenState state) {
  final controller = TextEditingController();
  String? selectedSeat;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Join Watch Party"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter 6-digit code"),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            hint: const Text("Select your seat",
                style: TextStyle(color: Colors.white70)),
            items: const [
              DropdownMenuItem(value: 'A1', child: Text('A1')),
              DropdownMenuItem(value: 'A2', child: Text('A2')),
              DropdownMenuItem(value: 'B1', child: Text('B1')),
              DropdownMenuItem(value: 'B2', child: Text('B2')),
              DropdownMenuItem(value: 'C1', child: Text('C1')),
              DropdownMenuItem(value: 'C2', child: Text('C2')),
            ],
            onChanged: (value) => selectedSeat = value,
          ),
        ],
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      backgroundColor: Colors.black87,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Provider.of<SettingsProvider>(context, listen: false)
                    .accentColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () async {
            final isValid = await validatePartyCode(controller.text, state);
            if (!context.mounted) return;
            if (isValid && selectedSeat != null) {
              state.joinParty(controller.text, selectedSeat!);
              Navigator.pop(dialogContext);
              showSuccess(context, "Successfully joined party");
              if (state.inviteJoinCount % 2 == 0) {
                showTriviaDialog(context, state);
              }
            } else {
              showError(context,
                  "Invalid or expired party code or seat not selected");
            }
            controller.dispose();
          },
          child: const Text("Join", style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

Future<bool> validatePartyCode(String code, WatchPartyScreenState state) async {
  if (code.length != 6) return false;
  try {
    final partyDoc = await FirebaseFirestore.instance
        .collection('watch_parties')
        .doc(code)
        .get();
    if (!partyDoc.exists || partyDoc.data()?['isActive'] != true) return false;
    final expiryTime = DateTime.parse(partyDoc.data()?['expiryTime']);
    return DateTime.now().isBefore(expiryTime);
  } catch (e) {
    showError(state.context, "Error validating code: $e");
    return false;
  }
}

void scheduleParty(int delayMinutes, Map<String, dynamic> movie,
    WatchPartyScreenState state) async {
  if (state.trialTickets <= 0 && !state.isPremium) {
    state.doorsController.forward();
    return;
  }
  try {
    state.startPartyScheduling(delayMinutes);
    await state.savePartyToFirestore(state.partyCode!, movie, delayMinutes);
    await fetchStreamingLinks(movie, state);
    if (!state.mounted) return;
    state.curtainController.forward();
    startPartyTimer(state);
    showSuccess(state.context,
        "Party scheduled for $delayMinutes minutes. Code: ${state.partyCode}");
  } catch (e) {
    if (!state.mounted) return;
    showError(state.context, "Failed to schedule party: $e");
  } finally {
    if (!state.mounted) return;
    state.stopPartyScheduling();
  }
}

void startPartyTimer(WatchPartyScreenState state) {
  state.startPartyTimer(() {
    if (!state.mounted) return;
    if (state.remainingMinutes <= 0) {
      endParty(state);
    }
  });
  if (Random().nextInt(10) < 2) {
    Future.delayed(const Duration(seconds: 10), () {
      if (!state.mounted) return;
      showSuccess(state.context, "An usher walks by...");
    });
  }
}

void endParty(WatchPartyScreenState state) {
  if (!state.mounted) return;
  state.endParty();
  state.curtainController.reverse();
  showSuccess(state.context, "Party has ended");
}

void showScheduleDialog(BuildContext context, Map<String, dynamic> movie,
    WatchPartyScreenState state) {
  final controller = TextEditingController(text: "5");
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text("Schedule ${movie['title']}"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: "Start in (minutes)",
          hintText: "Enter minutes",
        ),
        keyboardType: TextInputType.number,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      backgroundColor: Colors.black87,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Provider.of<SettingsProvider>(context, listen: false)
                    .accentColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () {
            final minutes = int.tryParse(controller.text) ?? 5;
            state.setMovieTitle(movie['title'] as String? ?? "Untitled");
            scheduleParty(minutes, movie, state);
            Navigator.pop(dialogContext);
            controller.dispose();
          },
          child: const Text("Schedule", style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

void showTriviaDialog(BuildContext context, WatchPartyScreenState state) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Movie Trivia Time!"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("What's the name of the director of this movie?"),
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Your answer"),
          ),
        ],
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      backgroundColor: Colors.black87,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                Provider.of<SettingsProvider>(context, listen: false)
                    .accentColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onPressed: () {
            state.addTriviaMessage(controller.text);
            Navigator.pop(dialogContext);
            showSuccess(context, "Trivia answer submitted!");
            controller.dispose();
          },
          child: const Text("Submit", style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}
