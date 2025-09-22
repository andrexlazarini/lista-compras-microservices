
# Guia de Testes — Lista de Compras (Microsserviços)

## Pré‑requisitos
- Node.js 18+ e npm 8+
- PowerShell (Windows) **ou** extensões REST Client no VS Code

## 1) Instalação
```powershell
cd /mnt/data/lista-compras-microservices/lista-compras-microservices-main
npm run install:all
```

## 2) Subir todos os serviços
```powershell
npm start
```
*Isso inicia:* User (3001), List (3002), Item (3003) e API Gateway (3000).

## 3) Health e Registro
```powershell
curl http://localhost:3000/health
curl http://localhost:3000/registry
```

## 4) Teste Automatizado
### Opção A — Node script
```powershell
node client-demo.js
```

### Opção B — PowerShell
```powershell
./smoke-tests.ps1
```

### Opção C — VS Code REST Client
Abra `smoke-tests.http` e clique em **Send Request** nas seções.

## Observações
- O catálogo agora inclui **Padaria** (Pão Francês, Pão de Forma Integral, Bolo de Fubá, Broa de Milho).
- Se você já tiver o usuário `admin`, o script de registro criará um novo usuário `john.doe`/`jane.doe` para os testes.
- O gateway implementa *circuit breaker* simples (3 falhas → abre por 30s), *health checks* a cada 30s e logs (morgan).
