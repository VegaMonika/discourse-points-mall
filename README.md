# Plugin Discourse Loja de Pontos

Plugin completo de loja de pontos para Discourse, integrado ao discourse-gamification. Pontos ganhos por atividade na comunidade (posts, respostas, curtidas, visitas diárias) e check-ins podem ser trocados por cosméticos virtuais ou produtos físicos.

## Funcionalidades

### 1. Check-in Diário (签到)
- Check-in diário para ganhar pontos
- Sequências consecutivas ganham bônus
- Calendário mensal, histórico e ranking
- Cards de reposição para repor dias perdidos (máx. 3/mês, preço escalonado, reset mensal)

### 2. Loja de Pontos (积分商店)
- Troque pontos por cosméticos virtuais ou produtos físicos
- Categorias, destaques e prateleiras na vitrine
- Controle de estoque e acompanhamento de pedidos
- Card de reposição integrado com preço escalonado (1000 / 3000 / 5000, configurável)

### 3. Inventário (背包)
- Cosméticos virtuais ficam no inventário e podem ser equipados/desequipados:
  - Título personalizado (头衔)
  - Moldura de avatar (头像框)
  - Borda de card (卡片边框)
  - Fundo de perfil (主页背景)
  - Assinatura de post (帖子签名)
  - Brilho SVIP (SVIP 光效)
  - Skin de tema (主题皮肤)
- Cosméticos com prazo expiram automaticamente via job diário

### 4. Pedidos e Endereços (订单与地址)
- Histórico de pedidos com status
- Caderno de endereços para produtos físicos

### 5. Extrato de Pontos (积分明细)
- Todas as entradas e saídas em uma linha do tempo
- Inclui pontos automáticos da comunidade via discourse-gamification
  (posts, respostas, curtidas recebidas/dadas, visitas diárias, etc. — últimos 90 dias)
- Filtro por entradas / saídas / check-in / loja / comunidade

### 6. Painel Admin (管理后台)
- Gerenciar produtos (criar / editar / excluir, estoque, categorias, campos da vitrine)
- Revisar e atualizar pedidos
- Consultar registros de check-in
- Configurar preços escalonados do card de reposição

## Instalação

1. Adicione o plugin à sua instalação Discourse:
```bash
cd /var/discourse
git clone https://github.com/Segreverso/discourse-points-segredin.git plugins/discourse-points-*
```

2. Reconstrua o container:
```bash
./launcher rebuild app
```

## Configuração

Ative o plugin em Admin > Configurações > Plugins > discourse-points-mall

Configurações disponíveis:

| Configuração | Padrão | Descrição |
| --- | --- | --- |
| `points_mall_enabled` | `true` | Ativar/desativar o plugin |
| `points_mall_checkin_points` | `10` | Pontos por check-in diário |
| `points_mall_checkin_streak_bonus` | `5` | Bônus por check-ins consecutivos |
| `points_mall_makeup_price_tier_1` | `1000` | Preço do 1º card de reposição no mês |
| `points_mall_makeup_price_tier_2` | `3000` | Preço do 2º card de reposição no mês |
| `points_mall_makeup_price_tier_3` | `5000` | Preço do 3º card de reposição no mês |

## Requisitos

- Discourse 2.7.0 ou superior
- Plugin [discourse-gamification](https://github.com/discourse/discourse-gamification) (backend de pontos)

O plugin suporta tanto a API atual do gamification (`GamificationLeaderboardScore`)
quanto a legada (`GamificationScore`); o saldo do usuário é lido ao vivo do
primeiro leaderboard, sempre correspondendo aos totais.

## Uso

Após a instalação, acesse a Loja de Pontos em `/points-mall`. A loja inclui:

- **Check-in** (签到): check-in diário com sequência e calendário
- **Loja** (商店): navegue e compre produtos com pontos
- **Inventário** (背包): equipe/desequipe cosméticos
- **Pedidos** (我的订单): histórico e endereços de envio
- **Extrato** (积分明细): linha do tempo de entradas/saídas

## Esquema do Banco

O plugin cria as seguintes tabelas:

- `points_mall_products` — catálogo de produtos (categorias, campos da vitrine, estoque)
- `points_mall_orders` — pedidos dos usuários
- `points_mall_checkins` — registros de check-in
- `points_mall_addresses` — endereços de envio
- `points_mall_makeup_cards` — status mensal de compra/uso de cards de reposição

Cosméticos e seus prazos de expiração são armazenados como campos personalizados do usuário e limpos diariamente.

## Licença

Licença MIT
