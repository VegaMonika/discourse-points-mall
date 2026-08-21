# Roadmap Técnico e Documentação de Arquitetura — Discourse Points Mall

## Resumo Executivo e Registro do Sistema

Este documento registra a arquitetura técnica, modelo de dados, controladores Rails/Ember, componentes de interface (Glimmer/GJS), regras SCSS/CSS responsivas, além do histórico de incidentes de compilação e plano de desenvolvimento do plugin **Discourse Points Mall (Segredin)**.

---

## 1. Histórico de Versões e Alterações

| Versão | Data | Módulo Afetado | Resumo da Alteração |
| :--- | :--- | :--- | :--- |
| **v0.4.2** | 20/08/2026 | Ember Controller | Restauração da propriedade `hasFilteredOrders` no controller JS para validar o render de pedidos no template GJS. |
| **v0.4.1** | 20/08/2026 | SCSS Common / Ember JS | Compactação de altura nos cartões de pedidos no desktop e adição de paginação client-side com limite de 5 itens por página. |
| **v0.4.0** | 20/08/2026 | SCSS Mobile | Redesign das thumbnails de produtos para formato Badge de 36px com alinhamento flexbox e `object-fit: contain`. |
| **v0.3.9** | 20/08/2026 | JS Initializer / SCSS | Estabilização de ordem da navegação superior no Discourse (`forceAfter: true` + `order: 99 !important`). |
| **v0.3.8** | 20/08/2026 | SCSS Mobile | Refatoração de layout e responsividade da lista de histórico de pedidos no mobile. |
| **v0.3.7** | 20/08/2026 | SCSS Common | Restauração da linha do tempo (stepper de status de pedido) e bloco de cópia rápida de código. |
| **v0.3.6** | 20/08/2026 | SCSS Common | Ajuste de geometria (`border-radius: 8-10px`), eliminação de sombras duplas e alinhamento de cores do botão de check-in. |
| **v0.3.5** | 19/08/2026 | Rails Backend / GJS | Implementação do Ranking resiliente em 2 camadas (Gamification + SQL Fallback) e formatação de datas fixas (`DD/MM/YYYY`). |
| **v0.3.0** | 19/08/2026 | Rails DB / GJS / Admin | Arquitetura de produtos híbridos (Pontos da Comunidade ou Comprar em Reais R$ via Link Externo). |

---

## 2. Detalhamento Arquitetural das Funcionalidades

### 2.1. Arquitetura de Produtos Híbridos (Pontos vs. Venda Externa R$)

#### Modelagem de Dados e Backend Rails
- **Campos Adicionados (`points_mall_products`)**:
  - `price_brl` (`decimal`, precision: 10, scale: 2): Armazena o valor monetário do produto em Reais.
  - `external_url` (`text`): URL de checkout externo de plataformas parceiras (Hotmart, Kiwify, Mercado Pago).
- **Permissões Administrativas (`AdminProductsController`)**:
  - Whitelist de parâmetros `:price_brl` e `:external_url` atualizada nos métodos `create` e `update`.
- **Serialização da API (`PointsMallProductSerializer`)**:
  - Exposição direta dos campos no JSON consumido pelo frontend Ember.

#### Comportamento da Interface (`points-mall.gjs`)
- Quando a propriedade `external_url` está preenchida no objeto do produto:
  - O botão de resgate por pontos é desativado.
  - É renderizado um elemento de âncora `<a>` estilizado como `.btn-external-buy`, exibindo o valor em Reais (ex: `Comprar (R$ 29,90)`).
  - A ação abre o destino em nova aba (`target="_blank" rel="noopener noreferrer"`), sem debitar pontos do saldo do usuário no Discourse.
- Quando o campo `external_url` é nulo ou vazio, mantém-se a transação nativa por pontos.

---

### 2.2. Ranking Resiliente em Duas Camadas (Gamification + SQL Fallback)

#### Resiliência no Controller (`CheckinsController`)
A dependência única da tabela `gamification_score` era vulnerável a cenários onde a lista `#2` não existia ou não havia sido recalculada pelas tarefas assíncronas do Discourse.

1. **Camada Primária (Gamification Integration)**:
   - Tentativa de leitura do `GamificationLeaderboard` configurado no ID 2 ou do primeiro registro existente na tabela.
2. **Camada Secundária (Fallback SQL Nativo)**:
   - Caso a Camada 1 retorne vazia ou nula, o controller executa uma consulta direta na tabela `PointsMallCheckin`:
     `PointsMallCheckin.group(:user_id).sum(:points_earned)`
   - O resultado é ordenado e formatado nos TOP 10 usuários com maior saldo de pontos acumulados.
   - Isso garante atualização instantânea do ranking após cada check-in individual.

---

### 2.3. Padronização de Formatação de Data Estática (`DD/MM/YYYY`)

#### Resolução do Conflito com Script Global do Discourse
O Discourse força a alteração dinâmica de tags de data para tempo relativo ("há 2 horas", "há 5 dias"). Para dados transacionais e histórico de pedidos, é mandatória a exibição da data civil fixa.

#### Função Auxiliar de Conversão (`formatDateFixed`)
Declarada e utilizada nos módulos `.gjs` do frontend:
```javascript
function formatDateFixed(dateVal) {
  if (!dateVal) return "-";
  if (typeof dateVal === "string" && dateVal.match(/^\d{4}-\d{2}-\d{2}$/)) {
    const parts = dateVal.split("-");
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
  }
  const d = new Date(dateVal);
  if (isNaN(d.getTime())) return String(dateVal);
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
}
```

---

### 2.4. Estabilização do Item de Navegação no Header (Fix de Flutuação/Jittering)

#### Diagnóstico
A injeção do botão "Loja de Pontos" na barra de navegação principal (`#navigation-bar.nav.nav-pills`) sofria variação de posição dependendo da ordem assíncrona com que os scripts dos plugins eram executados no cliente.

#### Solução em Duas Camadas
1. **Camada Lógica (Initializer JS)**: Injeção do argumento `forceAfter: true` na chamada `addNavigationBarItem` dentro de `initializers/points-mall.js`.
2. **Camada Estética (Flexbox CSS)**: Aplicação da regra `.points-mall-nav { order: 99 !important; }` no SCSS global (`common/points-mall.scss`), travando o item deterministicamente na ponta direita do contêiner flex.

---

### 2.5. Redesign Responsivo e Compactação da Lista de Pedidos

#### Otimização Mobile (Badge 36px)
- **Problema**: Em resoluções móbiveis (< 480px), as thumbnails dos produtos usavam dimensões de 48px a 72px, estourando horizontalmente sobre o título do pedido e a linha do tempo.
- **Implementação**:
  - Redimensionamento da classe `.order-product-thumb` para o formato **Badge Compacto de 36px × 36px** (`flex: 0 0 36px; border-radius: 8px; padding: 2px;`).
  - Utilização de `object-fit: contain` nas imagens e `align-items: center` no contêiner `.order-card-header`.
  - Liberação de 90%+ da área útil de tela no celular para o título, código identificador `#ID`, custo em pontos e badges de status.

#### Compactação Desktop
- Redução do padding interno do cartão `.order-card` de 18px para `12px 16px`.
- Diminuição dos nós da linha do tempo (stepper) de 32px para `26px` (fonte `0.8em`), linhas conectoras ajustadas para `2px` de espessura e padding interno para `8px 14px`.

#### Sistema de Paginação Client-Side (`.orders-pagination`)
- **Capacidade**: Limite de 5 pedidos por página.
- **Navegação**: Controles para avançar (`nextOrdersPage`) e voltar (`prevOrdersPage`), com indicação centralizada do número da página atual em relação ao total (`Página X de Y`).
- **Reset de Estado**: Alternar entre as abas de filtro ("Todos", "Físicos", "Virtuais") reseta automaticamente a propriedade `ordersPage` para a primeira página.

---

## 3. Catálogo de Erros de Compilação e Resolução de Incêndios

### 3.1. Incidente de Compilação SCSS (`Discourse::ScssError: unmatched "}"`)
- **Causa**: Edição parcial no bloco `.order-copy-action` dentro de `common/points-mall.scss` que resultou no fechamento incorreto de chaves aninhadas.
- **Impacto**: Aborto na tarefa `rake assets:precompile` durante o build do Docker no Discourse.
- **Protocolo de Mitigação**: Obrigatoriedade de execução prévia de compilação sintática via Dart Sass (`npx sass`) no ambiente local antes do envio para controle de versão.

### 3.2. Incidente de Ocultação de Pedidos por Ausência de Getter Ember
- **Causa**: Durante a implementação do fluxo de paginação no controller JS `points-mall.js`, o getter `hasFilteredOrders` foi sobrescrito involuntariamente.
- **Impacto**: O template `.gjs` lia `@controller.hasFilteredOrders` como valor indefinido (falso) e desviava o fluxo para o bloco alternativo, exibindo "Nenhum pedido realizado" mesmo quando a API enviava registros válidos.
- **Resolução (v0.4.2)**: Restauração imediata do método `get hasFilteredOrders() { return this.filteredOrders.length > 0; }`.

---

## 4. Estrutura de Arquivos do Projeto

```
discourse-points-segredin/
├── ROADMAP.md                                                    # Documentação Técnica e Roadmap Oficial (v0.4.2)
├── plugin.rb                                                     # Registro da versão v0.4.2 e SVG Icons do Discourse
├── app/
│   └── controllers/
│       └── discourse_points_mall/
│           ├── admin_products_controller.rb                      # Sanitização de parâmetros price_brl e external_url
│           └── checkins_controller.rb                            # Algoritmo de ranking com Fallback SQL
├── assets/
│   ├── javascripts/discourse/
│   │   ├── initializers/points-mall.js                           # Registro do item no header (forceAfter: true)
│   │   ├── controllers/points-mall.js                            # Lógica de paginação, filtros e getters
│   │   └── templates/
│   │       ├── points-mall.gjs                                   # Layout principal da loja e histórico de pedidos
│   │       └── points-mall/
│   │           ├── checkin.gjs                                   # Visualização de check-ins com datas estáticas
│   │           └── orders.gjs                                    # Visualização de pedidos com datas estáticas
│   └── stylesheets/
│       ├── common/points-mall.scss                               # Regras desktop compactas, nav flex order e paginação
│       └── mobile/points-mall.scss                               # Layout responsivo e thumbnail em badge compacto (36px)
```

---

## 5. Cronograma de Desenvolvimento Futuro (Backlog)

1. **Integração de Gateway de Pagamento Automático**: Implementação de webhooks para conciliação bancária imediata e confirmação de pedidos externos.
2. **Notificações do Sistema para Alteração de Status**: Notificar o usuário via mensagens nativas do Discourse quando um pedido for marcado como enviado ou entregue.
3. **Módulo de Exportação de Dados Administrativos**: Disponibilizar gerador de relatórios em CSV/Excel para auditoria de resgates e movimentação de pontos.
