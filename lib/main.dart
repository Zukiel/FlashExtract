import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/flashcard_controller.dart';
// import '../views/parser_test_screen.dart';
import '../views/pipeline_test_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FlashcardController(),
      child: const FlashExtractApp(),
    ),
  );
}

class FlashExtractApp extends StatelessWidget {
  const FlashExtractApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashExtract',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PipelineTestScreen()
      // home: const ParserTestScreen()
      // home: const HomeScreen(),
    );
  }
}

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = context.watch<FlashcardController>();

//     return Scaffold(
//       appBar: AppBar(title: const Text('FlashExtract - Backend Demo')),
//       body: Center(
//         child: controller.state == ExtractionState.extracting
//             ? const CircularProgressIndicator()
//             : Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       context.read<FlashcardController>().extractAndCreateDeck(
//                             filePath: '/documents/lecture1.pdf', // MAKE THIS DRAG AND DROP FILE
//                             deckTitle: 'ICS26011 Lecture Notes', 
//                           );
//                     },
//                     child: const Text('Process Document'),
//                   ),
//                   if (controller.state == ExtractionState.error)
//                     Text(
//                       controller.errorMessage ?? '',
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   if (controller.state == ExtractionState.success)
//                     Text(
//                       'Success! Created Deck with ${controller.activeDeck?.cards.length} cards.',
//                       style: const TextStyle(color: Colors.green),
//                     ),
//                 ],
//               ),
//       ),
//     );
//   }
// }