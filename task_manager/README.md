# Task Manager Pro

Projeto Flutter pronto para abrir no Android Studio.

## Como rodar (primeira vez)
1. Instale Flutter e aceite licenças:
   ```bash
   flutter doctor
   flutter doctor --android-licenses
   ```
2. Dentro da pasta do projeto, gere as plataformas (Android/iOS/Windows etc.):
   ```bash
   flutter create .
   ```
   > Isso cria as pastas **android/**, **ios/**, **windows/**, **web/** etc.
3. Rode no emulador Android (ou dispositivo físico com Depuração USB):
   ```bash
   flutter run
   ```

## Observações
- O banco SQLite é criado automaticamente na primeira execução.
- Um registro de tarefa de exemplo será inserido se a tabela estiver vazia.
- O projeto usa **Material 3** (useMaterial3: true).