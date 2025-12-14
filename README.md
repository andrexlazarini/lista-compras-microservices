Link video mensageria: https://youtu.be/QpkSqYOrmkg


# Task Manager Offline-First + Upload de Fotos no S3 (LocalStack) — Etapa 3 (Opção B)

Este projeto atende à **Etapa 3 (Opção B: S3 com LocalStack)** do laboratório DAMD/PUC Minas, substituindo armazenamento local de fotos por armazenamento em um **bucket S3 simulado** (LocalStack). fileciteturn0file0

## O que foi implementado (Opção B)
- **Docker Compose** com **LocalStack (S3)** (porta **4566**)
- Bucket S3 local **`shopping-images`** criado automaticamente na inicialização
- **Backend (Node/Express)** com endpoint **`POST /upload`** que recebe `multipart/form-data` e salva no S3 (LocalStack)
- **Integração no App Flutter**: ao salvar tarefa com foto (online), a foto é enviada ao backend e a tarefa passa a ter `photoUrl`

> Observação: as tarefas continuam sendo persistidas em SQLite (offline-first). O upload para S3 ocorre quando há conexão.

---

## 1) Requisitos (instalar uma vez)
- Flutter SDK
- **Docker Desktop** (obrigatório para o LocalStack)
- Node.js 18+ (para rodar o backend de upload)
- (Opcional) AWS CLI, para validar via terminal

---

## 2) Subir o S3 local (LocalStack) com Docker
Na raiz do projeto:

```bash
docker compose up -d
```

Validar logs:

```bash
docker logs -f localstack-task-manager
```

---

## 3) Verificar se o bucket existe (AWS CLI)
Se você tiver AWS CLI instalado:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls
```

Você deve ver o bucket **shopping-images**.

---

## 4) Rodar o Backend de Upload (Node)
Em outro terminal, na pasta do backend:

```bash
cd backend/media_service
npm install
npm start
```

Teste rápido de saúde no navegador:

- `http://localhost:3001/health`

---

## 5) Rodar o App Flutter
Em outro terminal:

```bash
flutter pub get
flutter run
```

### Base URLs importantes (Android)
- Backend upload: `http://10.0.2.2:3001`
- LocalStack: `http://10.0.2.2:4566`

(10.0.2.2 é o “localhost do Windows” visto pelo **emulador Android**.)

---

## 6) Roteiro de Demonstração (Sala de Aula) — Opção B
1. **Infraestrutura:** `docker compose up -d` e mostrar LocalStack subindo
2. **Configuração:** `aws --endpoint-url=http://localhost:4566 s3 ls` e provar que `shopping-images` existe
3. **Ação no app:** tirar uma foto e salvar a tarefa (online)
4. **Validação:** listar objetos do bucket:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://shopping-images/tasks/ --recursive
```

---

## Estrutura adicionada
- `docker-compose.yml` (LocalStack S3)
- `backend/localstack-init/01-create-bucket.sh` (criação do bucket)
- `backend/media_service/` (API de upload)
- `lib/services/media_service.dart` (client de upload no Flutter)



