# Jogo de Adivinhação — Docker Compose

Estrutura containerizada do [guess_game](https://github.com/fams/guess_game), orquestrada com Docker Compose. O backend Flask, o frontend React, o banco Postgres e o proxy NGINX rodam em containers separados, com balanceamento de carga e persistência de dados.

## URL de acesso

Após subir os serviços, acesse:

**http://localhost:8080**

O NGINX é o único ponto de entrada exposto. Toda a navegação (frontend) e as chamadas de API (`/create`, `/guess/`) passam por essa URL.

---

## Estrutura do repositório

| Arquivo | Descrição |
|---------|-----------|
| `docker-compose.yml` | Orquestração dos serviços |
| `Dockerfile` | Imagem do backend Flask (Python 3.12) |
| `frontend/Dockerfile` | Build do React (Node 18) e serviço dos arquivos estáticos via NGINX |
| `nginx.conf` | Proxy reverso e balanceamento de carga entre instâncias do backend |
| `frontend/default.conf` | Configuração NGINX interna do container frontend (SPA React Router) |

---

## Decisões de design

### Serviços

A aplicação foi dividida em cinco serviços:

```
Usuário → nginx:8080
              ├── /create, /guess/, /health → backend-1 / backend-2 :5000
              └── /                         → frontend :80
                                              backend-* → postgres :5432
```

| Serviço | Imagem / build | Função |
|---------|----------------|--------|
| `postgres` | `postgres:16` | Armazena os dados do jogo |
| `backend-1`, `backend-2` | `guess-backend:1.0` (build local) | Duas instâncias Flask para balanceamento |
| `frontend` | `guess-frontend:1.0` (build local) | React compilado, servido por NGINX interno |
| `nginx` | `nginx:alpine` | Proxy reverso e ponto de entrada público |

Foram usadas **duas instâncias explícitas** do backend (`backend-1` e `backend-2`) em vez de escala dinâmica, para deixar o balanceamento no NGINX explícito e previsível.

### Rede

Todos os serviços compartilham a **rede padrão** criada pelo Docker Compose. Os containers se comunicam pelo **nome do serviço** como hostname (ex.: `postgres`, `frontend`, `backend-1`). Por isso o backend usa `FLASK_DB_HOST=postgres` e não `localhost`.

### Volumes

| Volume | Montagem | Finalidade |
|--------|----------|------------|
| `pgdata` | `/var/lib/postgresql/data` no Postgres | Persistência dos dados do banco entre reinícios e recriações de containers |

Os dados do jogo sobrevivem a `docker compose down`. Para apagar o banco, remova o volume com `docker compose down -v`.

### Balanceamento de carga

O arquivo `nginx.conf` define um bloco `upstream backend_pool` com as duas instâncias do backend:

```nginx
upstream backend_pool {
    server backend-1:5000;
    server backend-2:5000;
}
```

O NGINX distribui as requisições de `/create`, `/guess/` e `/health` entre as duas instâncias em **round-robin** (comportamento padrão). As demais rotas são encaminhadas ao container `frontend`.

O frontend foi compilado com `REACT_APP_BACKEND_URL` vazio, fazendo requisições relativas (`/create`, `/guess/...`) para a mesma origem — o proxy NGINX encaminha essas chamadas ao backend sem alterar o código-fonte da aplicação.

### Resiliência

- **`restart: always`** em todos os serviços: containers reiniciam automaticamente após falha.
- **Healthcheck no Postgres**: os backends só iniciam quando o banco está pronto (`depends_on` com `condition: service_healthy`).

### Versões

Conforme o projeto original:

- **Python 3.12** (`python:3.12-slim`) no backend
- **Node 18** (`node:18-alpine`) no build do frontend

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado
- [Docker Compose](https://docs.docker.com/compose/) (incluso no Docker Desktop)

---

## Instalação e execução

1. Clone o repositório:

   ```bash
   git clone <url-do-repositorio>
   cd puc_docker_guess_game
   ```

2. Suba todos os serviços (build na primeira execução ou após alterações no código):

   ```bash
   docker compose up --build
   ```

   Para rodar em segundo plano:

   ```bash
   docker compose up --build -d
   ```

3. Acesse **http://localhost:8080** no navegador.

4. Para verificar se os backends estão respondendo:

   ```bash
   curl http://localhost:8080/health
   ```

   Resposta esperada: `{"status":"ok"}`

### Parar os serviços

```bash
docker compose down
```

Os dados do Postgres permanecem no volume `pgdata`. Para remover também o volume:

```bash
docker compose down -v
```

---

## Como jogar

1. Acesse **http://localhost:8080**
2. Na tela inicial (Maker), digite uma frase secreta e crie um jogo
3. Anote o `game_id` retornado
4. Vá para a rota **Breaker** e tente adivinhar a senha usando o `game_id`

---

## Atualização de componentes

Cada componente pode ser atualizado trocando a versão da imagem ou reconstruindo o build, sem alterar o código das aplicações.

### Backend

Altere a tag no `docker-compose.yml`:

```yaml
image: guess-backend:2.0
```

Reconstrua e suba:

```bash
docker compose build backend-1 backend-2
docker compose up -d
```

### Frontend

Altere a tag no `docker-compose.yml`:

```yaml
image: guess-frontend:2.0
```

Reconstrua e suba:

```bash
docker compose build frontend
docker compose up -d
```

### Postgres

Altere a versão da imagem no `docker-compose.yml`:

```yaml
image: postgres:17
```

Reconstrua e suba:

```bash
docker compose up -d
```

> **Atenção:** ao atualizar o Postgres, verifique compatibilidade de dados no volume `pgdata`.

### NGINX (proxy)

A configuração é montada via volume (`./nginx.conf`). Após editar o arquivo:

```bash
docker compose restart nginx
```

Não é necessário rebuild — basta reiniciar o serviço.

### Quando usar `--build`

| Situação | Comando |
|----------|---------|
| Primeira execução ou código alterado | `docker compose up --build` |
| Apenas reiniciar sem mudanças | `docker compose up -d` |
| Só alterou `nginx.conf` | `docker compose restart nginx` |

---

## Comandos úteis

```bash
# Logs de todos os serviços
docker compose logs -f

# Logs de um serviço específico
docker compose logs -f backend-1

# Status dos containers
docker compose ps

# Reconstruir apenas o backend
docker compose build backend-1 backend-2
```

---

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).
