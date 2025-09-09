// deploy.dart
import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  // --- INÍCIO DA CORREÇÃO ---
  // Define os nomes dos comandos corretos dependendo do sistema operacional
  final flutterCommand = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final firebaseCommand = Platform.isWindows ? 'firebase.cmd' : 'firebase';
  // --- FIM DA CORREÇÃO ---

  // 1. Encontrar e ler o arquivo version.json
  final versionFile = File('web/version.json');
  if (!await versionFile.exists()) {
    print('Erro: Arquivo web/version.json não encontrado!');
    exit(1);
  }

  final content = await versionFile.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;
  final versionString = json['version'] as String? ?? '1.0.0';

  // 2. Incrementar a versão
  final parts = versionString.split('.').map(int.parse).toList();
  parts[2]++; // Incrementa o patch
  final newVersion = parts.join('.');
  json['version'] = newVersion;

  // 3. Salvar o arquivo com a nova versão
  await versionFile.writeAsString(jsonEncode(json));
  print('✅ Versão atualizada para: $newVersion');

  // 4. Executar o build do Flutter para web (usando o comando corrigido)
  print('\n⏳ Iniciando build do Flutter...');
  await runProcess(flutterCommand, ['build', 'web', '--wasm']);
  print('✅ Build concluído com sucesso!');

  // 5. Executar o deploy no Firebase (usando o comando corrigido)
  print('\n🚀 Iniciando deploy no Firebase...');
  await runProcess(firebaseCommand, ['deploy', '--only', 'hosting']);
  print('🎉 Deploy finalizado com sucesso para a versão $newVersion!');
}

// Função auxiliar para rodar comandos no terminal
Future<void> runProcess(String command, List<String> args) async {
  print('Executando: $command ${args.join(' ')}');
  final result = await Process.run(command, args);

  if (result.stdout.toString().isNotEmpty) {
    print(result.stdout);
  }

  if (result.exitCode != 0) {
    print('Erro ao executar o comando:');
    if (result.stderr.toString().isNotEmpty) {
      print(result.stderr);
    }
    exit(1);
  }
}