import { Input } from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq, gt, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

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

function formatBrl(val) {
  if (val === null || val === undefined || val === "") return "";
  const num = Number(val);
  if (isNaN(num)) return String(val);
  if (Number.isInteger(num)) {
    return num.toString();
  }
  return num.toFixed(2).replace(".", ",");
}

export default <template>
  <div class="points-mall-container">
    <div class="points-mall-header-card">
      <div class="points-mall-brand">
        <div class="points-mall-brand-icon">{{dIcon "gift"}}</div>
        <div>
          <h1>{{i18n "points_mall.title"}}</h1>
          <p>{{i18n "points_mall.subtitle"}}</p>
        </div>
      </div>

      <div class="points-balance-card">
        <span>{{i18n "points_mall.balance"}}</span>
        <strong>{{@controller.currentUser.points_balance}}</strong>
      </div>
    </div>

    <div class="points-mall-nav-shell">
      <div class="points-mall-nav">
        {{#each @controller.tabs as |tab|}}
          <button
            type="button"
            class="points-mall-nav-item
              {{if (eq @controller.activeTab tab.name) 'active'}}"
            aria-current={{if
              (eq @controller.activeTab tab.name)
              "page"
              "false"
            }}
            {{on "click" (fn @controller.switchTab tab.name)}}
          >
            {{dIcon tab.icon}}
            <span>{{i18n (concat "points_mall.nav." tab.name)}}</span>
          </button>
        {{/each}}
      </div>
    </div>

    <div class="points-mall-content">
      {{#if (eq @controller.activeTab "checkin")}}
        <div class="points-mall-checkin">
          <div class="checkin-overview-grid">
            <article class="checkin-summary-card">
              <div class="checkin-summary-head">
                <h2>{{i18n "points_mall.checkin.title"}}</h2>

                {{#if @controller.checkinSummary.checked_in_today}}
                  <div class="already-checked-in">
                    {{i18n "points_mall.checkin.already_checked"}}
                  </div>
                {{else}}
                  <DButton
                    @action={{@controller.checkin}}
                    @label="points_mall.checkin.button"
                    @icon="calendar-check"
                    class="btn-primary checkin-button"
                  />
                {{/if}}
              </div>

              <div class="checkin-stats-grid">
                <article class="checkin-stat-item">
                  <span class="stat-label">{{i18n
                      "points_mall.checkin.current_streak_label"
                    }}</span>
                  <strong
                    class="stat-value"
                  >{{@controller.checkinSummary.current_streak}}</strong>
                </article>
                <article class="checkin-stat-item">
                  <span class="stat-label">{{i18n
                      "points_mall.checkin.month_checkins_label"
                    }}</span>
                  <strong
                    class="stat-value"
                  >{{@controller.checkinSummary.current_month_checkins}}</strong>
                </article>
                <article class="checkin-stat-item">
                  <span class="stat-label">{{i18n
                      "points_mall.checkin.my_rank_label"
                    }}</span>
                  <strong class="stat-value">
                    {{#if @controller.checkinSummary.my_rank}}
                      {{@controller.checkinSummary.my_rank}}
                      {{i18n "points_mall.checkin.rank_suffix"}}
                    {{else}}
                      -
                    {{/if}}
                  </strong>
                </article>
                <article class="checkin-stat-item">
                  <span class="stat-label">{{i18n
                      "points_mall.checkin.current_level_label"
                    }}</span>
                  <strong
                    class="stat-value"
                  >{{@controller.levelProgress.current_name}}</strong>
                </article>
              </div>
            </article>

            <article class="checkin-level-card">
              <div class="checkin-level-head">
                <h3>{{i18n "points_mall.checkin.progress_title"}}</h3>
                <span
                  class="level-badge"
                >{{@controller.levelProgress.current_name}}</span>
              </div>
              <p class="checkin-level-subtitle">
                {{i18n
                  "points_mall.checkin.progress_subtitle"
                  level=@controller.levelProgress.current_name
                }}
              </p>
              <div class="checkin-level-progress">
                <div
                  class="checkin-level-progress-bar"
                  style={{@controller.levelProgressStyle}}
                ></div>
              </div>
              <p class="checkin-level-next">
                {{#if @controller.levelProgress.next_name}}
                  {{i18n
                    "points_mall.checkin.next_level_label"
                    next=@controller.levelProgress.next_name
                  }}
                  ·
                  {{@controller.levelProgress.requirement_text}}
                {{else}}
                  {{i18n "points_mall.checkin.max_level"}}
                {{/if}}
              </p>
            </article>
          </div>

          <div class="checkin-main-grid">
            <article class="checkin-calendar-card">
              <div class="checkin-calendar-head">
                <h3>{{i18n "points_mall.checkin.calendar_title"}}</h3>
                <div class="checkin-calendar-head-actions">
                  <span
                  >{{@controller.checkinSummary.month_progress_percent}}%</span>
                  <button
                    type="button"
                    class="btn btn-small checkin-buy-makeup-btn
                      {{if @controller.canBuyMakeupCard 'btn-primary'}}"
                    {{on "click" @controller.buyMakeupCard}}
                    disabled={{not @controller.canBuyMakeupCard}}
                  >
                    {{i18n @controller.makeupBuyButtonLabel}}
                  </button>
                </div>
              </div>
              <p class="checkin-calendar-tip">
                {{i18n
                  "points_mall.checkin.calendar_tip"
                  purchased=@controller.makeupCardStatus.purchased_count
                  used=@controller.makeupCardStatus.used_count
                  remain=@controller.makeupCardStatus.available_count
                }}
              </p>

              <div class="checkin-weekday-row">
                {{#each @controller.calendarWeekdayKeys as |weekday|}}
                  <span>{{i18n
                      (concat "points_mall.checkin.weekdays." weekday)
                    }}</span>
                {{/each}}
              </div>

              <div class="checkin-calendar-grid">
                {{#each @controller.monthCalendarCells as |day|}}
                  {{#if day.placeholder}}
                    <div class="checkin-day-cell placeholder"></div>
                  {{else}}
                    <div class="checkin-day-cell status-{{day.status}}">
                      <strong>{{day.day}}</strong>
                      <span>{{i18n
                          (concat
                            "points_mall.checkin.calendar_status." day.status
                          )
                        }}</span>
                      {{#if day.can_makeup}}
                        <button
                          type="button"
                          class="btn btn-small btn-primary checkin-makeup-btn"
                          {{on "click" (fn @controller.makeUpCheckin day)}}
                        >
                          {{i18n "points_mall.checkin.makeup_action"}}
                        </button>
                      {{/if}}
                    </div>
                  {{/if}}
                {{/each}}
              </div>
            </article>

            <aside class="checkin-ranking-card">
              <div class="checkin-ranking-head">
                <h3>{{dIcon "trophy"}}
                  {{i18n "points_mall.checkin.ranking_title"}}</h3>
                <span>{{i18n
                    "points_mall.checkin.ranking_my_points"
                    points=@controller.checkinSummary.my_score
                  }}</span>
              </div>

              {{#if @controller.hasRankingUsers}}
                <div class="checkin-ranking-list">
                  {{#each @controller.rankingUsers as |row|}}
                    <article class="checkin-ranking-item">
                      <span class="rank-order">{{row.rank}}</span>
                      <div class="rank-user">
                        {{#if row.avatar_url}}
                          <img src={{row.avatar_url}} alt={{row.username}} />
                        {{else}}
                          <div class="rank-avatar-fallback">{{dIcon
                              "user"
                            }}</div>
                        {{/if}}
                        <div>
                          <strong>{{row.username}}</strong>
                          <small>{{row.level_name}}</small>
                        </div>
                      </div>
                      <span class="rank-points">{{row.points}}</span>
                    </article>
                  {{/each}}
                </div>
              {{else}}
                <p class="checkin-ranking-empty">{{i18n
                    "points_mall.checkin.ranking_empty"
                  }}</p>
              {{/if}}
            </aside>
          </div>

          <div class="checkin-history">
            <h3>{{i18n "points_mall.checkin.history"}}</h3>

            <div class="checkin-history-table-wrap">
              <table class="checkin-table">
                <thead>
                  <tr>
                    <th>{{i18n "points_mall.checkin.date"}}</th>
                    <th>{{i18n "points_mall.checkin.points"}}</th>
                    <th>{{i18n "points_mall.checkin.current_streak_label"}}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each @controller.model.checkins as |checkin|}}
                    <tr>
                      <td>{{formatDateFixed checkin.checkin_date}}</td>
                      <td>{{checkin.points_earned}}</td>
                      <td>{{checkin.streak_days}}</td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      {{/if}}

      {{#if (eq @controller.activeTab "shop")}}
        <div class="points-mall-shop">
          <div class="shop-command-bar">
            <div class="shop-command-balance">
              <span class="shop-command-balance-icon">{{dIcon "coins"}}</span>
              <strong>{{@controller.currentUser.points_balance}}</strong>
              <span>{{i18n "points_mall.storefront.points_unit"}}</span>
            </div>

            <label class="shop-command-search">
              {{dIcon "magnifying-glass"}}
              <Input
                @value={{@controller.shopKeyword}}
                aria-label={{i18n "points_mall.shop.search_placeholder"}}
                placeholder={{i18n "points_mall.shop.search_placeholder"}}
                class="shop-search-input"
                {{on "input" @controller.updateShopKeyword}}
              />
            </label>

            <div class="shop-command-actions">
              <button
                type="button"
                class="shop-command-action"
                title={{i18n "points_mall.nav.orders"}}
                aria-label={{i18n "points_mall.nav.orders"}}
                {{on "click" (fn @controller.switchTab "orders")}}
              >
                {{dIcon "receipt"}}
              </button>
              <button
                type="button"
                class="shop-command-action"
                title={{i18n "points_mall.nav.ledger"}}
                aria-label={{i18n "points_mall.nav.ledger"}}
                {{on "click" (fn @controller.switchTab "ledger")}}
              >
                {{dIcon "wallet"}}
              </button>
            </div>
          </div>

          <section class="shop-storefront-hero">
            <div class="shop-promo-banner">
              <div class="shop-promo-copy">
                <span>{{i18n "points_mall.storefront.eyebrow"}}</span>
                <h2>{{i18n "points_mall.storefront.hero_title"}}</h2>
                <p>{{i18n "points_mall.storefront.hero_tip"}}</p>
                <button
                  type="button"
                  class="btn shop-promo-button"
                  {{on "click" (fn @controller.switchTab "checkin")}}
                >
                  {{dIcon "calendar-check"}}
                  {{i18n "points_mall.storefront.checkin_cta"}}
                </button>
              </div>
              <div class="shop-promo-visual" aria-hidden="true">
                <span class="shop-promo-orbit orbit-one"></span>
                <span class="shop-promo-orbit orbit-two"></span>
                {{dIcon "gift"}}
              </div>
            </div>

            <aside class="shop-member-card">
              <div class="shop-member-head">
                <span class="shop-member-avatar">{{dIcon "user"}}</span>
                <div>
                  <small>{{i18n "points_mall.storefront.welcome_back"}}</small>
                  <strong>{{@controller.currentUser.username}}</strong>
                </div>
              </div>
              <div class="shop-member-points">
                <span>{{i18n "points_mall.storefront.available_points"}}</span>
                <strong>{{@controller.currentUser.points_balance}}</strong>
                <small>{{i18n "points_mall.storefront.points_tip"}}</small>
              </div>
              <div class="shop-member-links">
                <button
                  type="button"
                  {{on "click" (fn @controller.switchTab "orders")}}
                >{{dIcon "receipt"}}{{i18n "points_mall.nav.orders"}}</button>
                <button
                  type="button"
                  {{on "click" (fn @controller.switchTab "ledger")}}
                >{{dIcon "wallet"}}{{i18n "points_mall.nav.ledger"}}</button>
                <button
                  type="button"
                  {{on "click" (fn @controller.switchTab "checkin")}}
                >{{dIcon "calendar-check"}}{{i18n
                    "points_mall.nav.checkin"
                  }}</button>
              </div>
            </aside>
          </section>

          <div class="shop-header">
            <div>
              <h2>{{i18n "points_mall.shop.title"}}</h2>
              <p class="shop-header-subtitle">{{i18n
                  "points_mall.shop.header_tip"
                }}</p>
            </div>
            <span class="shop-total-count">
              {{i18n
                "points_mall.shop.total_count"
                count=@controller.filteredShopProducts.length
              }}
            </span>
          </div>

          <div class="shop-insight-grid">
            <article class="shop-insight-card">
              <span>{{i18n "points_mall.shop.insights.product_count"}}</span>
              <strong>{{@controller.shopInsights.productCount}}</strong>
            </article>
            <article class="shop-insight-card">
              <span>{{i18n "points_mall.shop.insights.category_count"}}</span>
              <strong>{{@controller.shopInsights.categoryCount}}</strong>
            </article>
            <article class="shop-insight-card">
              <span>{{i18n "points_mall.shop.insights.featured_count"}}</span>
              <strong>{{@controller.shopInsights.featuredCount}}</strong>
            </article>
            <article class="shop-insight-card">
              <span>{{i18n "points_mall.shop.insights.redeemed_count"}}</span>
              <strong>{{@controller.shopInsights.redeemedCount}}</strong>
            </article>
          </div>

          {{#if @controller.model.products.length}}
            <div class="shop-toolbar">
              <div class="shop-nav-bar">
                <div class="shop-type-pills">
                  {{#each @controller.shopTypeFilters as |filter|}}
                    <button
                      type="button"
                      class="shop-filter-chip
                        {{if (eq @controller.shopTypeFilter filter) 'active'}}"
                      aria-pressed={{if
                        (eq @controller.shopTypeFilter filter)
                        "true"
                        "false"
                      }}
                      {{on "click" (fn @controller.setShopTypeFilter filter)}}
                    >
                      {{i18n (concat "points_mall.shop.filters.type." filter)}}
                    </button>
                  {{/each}}
                </div>

                <div class="shop-search-box">
                  {{dIcon "magnifying-glass"}}
                  <Input
                    @value={{@controller.shopKeyword}}
                    aria-label={{i18n "points_mall.shop.search_placeholder"}}
                    placeholder={{i18n "points_mall.shop.search_placeholder"}}
                    class="shop-search-input"
                  />
                </div>
              </div>

              <div class="shop-secondary-row">
                <div class="shop-filter-scroll">
                  {{#each @controller.shopCategoryOptions as |option|}}
                    <button
                      type="button"
                      class="shop-filter-chip
                        {{if
                          (eq @controller.shopCategoryFilter option.key)
                          'active'
                        }}"
                      aria-pressed={{if
                        (eq @controller.shopCategoryFilter option.key)
                        "true"
                        "false"
                      }}
                      {{on
                        "click"
                        (fn @controller.setShopCategoryFilter option.key)
                      }}
                    >
                      {{option.label}}
                    </button>
                  {{/each}}

                  <span class="shop-filter-divider"></span>

                  {{#each @controller.shopSortOptions as |sort|}}
                    <button
                      type="button"
                      class="shop-sort-chip
                        {{if (eq @controller.shopSort sort) 'active'}}"
                      aria-pressed={{if
                        (eq @controller.shopSort sort)
                        "true"
                        "false"
                      }}
                      {{on "click" (fn @controller.setShopSort sort)}}
                    >
                      {{i18n (concat "points_mall.shop.sort." sort)}}
                    </button>
                  {{/each}}
                </div>
              </div>
            </div>

            {{#if @controller.filteredShopProducts.length}}
              {{#if @controller.showFeaturedShelf}}
                <section class="shop-featured-shelf">
                  <div class="shop-section-head">
                    <div>
                      <h3>{{i18n "points_mall.shop.featured_title"}}</h3>
                      <p>{{i18n "points_mall.shop.featured_tip"}}</p>
                    </div>
                    <span>
                      {{i18n
                        "points_mall.shop.section_count"
                        count=@controller.featuredShopProducts.length
                      }}
                    </span>
                  </div>

                  <div class="shop-featured-grid">
                    {{#each @controller.featuredShopProducts as |product|}}
                      <div class="product-card is-featured">
                        {{#if product.badge_text}}
                          <span
                            class="product-corner-badge"
                          >{{product.badge_text}}</span>
                        {{else if product.featured}}
                          <span class="product-corner-badge">
                            {{i18n "points_mall.shop.badges.featured"}}
                          </span>
                        {{/if}}

                        {{#if product.image_url}}
                          <div class="product-image">
                            <img
                              src={{product.image_url}}
                              alt={{product.name}}
                            />
                          </div>
                        {{else}}
                          <div class="product-image product-image-placeholder">
                            {{dIcon "gift"}}
                          </div>
                        {{/if}}

                        <div class="product-info">
                          <div class="product-badges">
                            <span class="product-category-badge">
                              {{#if product.category}}
                                {{product.category}}
                              {{else if (eq product.product_type "physical")}}
                                {{i18n
                                  "points_mall.shop.filters.category.default_physical"
                                }}
                              {{else}}
                                {{i18n
                                  "points_mall.shop.filters.category.default_virtual"
                                }}
                              {{/if}}
                            </span>
                            <span
                              class="product-type-badge type-{{product.product_type}}"
                            >
                              {{i18n
                                (concat
                                  "points_mall.shop.type." product.product_type
                                )
                              }}
                            </span>
                          </div>

                          <h3>{{product.name}}</h3>
                          <p>{{product.description}}</p>
                          <div class="product-meta">
                            <span class="product-cost">
                              {{#if product.price_brl}}
                                R$ {{formatBrl product.price_brl}}
                              {{else}}
                                {{i18n
                                  "points_mall.shop.cost"
                                  points=product.points_cost
                                }}
                              {{/if}}
                            </span>
                            <span class="product-stock">
                              {{#if (eq product.stock -1)}}
                                {{i18n "points_mall.shop.unlimited"}}
                              {{else if (gt product.stock 0)}}
                                {{i18n
                                  "points_mall.shop.stock"
                                  count=product.stock
                                }}
                              {{else}}
                                {{i18n "points_mall.shop.out_of_stock"}}
                              {{/if}}
                            </span>
                          </div>
                          <div class="product-stats-row">
                            <span>
                              {{i18n
                                "points_mall.shop.redeemed_count"
                                count=product.redeemed_count
                              }}
                            </span>
                          </div>

                          {{#if product.is_makeup_card}}
                            <div class="product-makeup-meta">
                              <p>
                                {{i18n
                                  "points_mall.shop.makeup.monthly_status"
                                  purchased=product.makeup_card.purchased_count
                                  used=product.makeup_card.used_count
                                  remain=product.makeup_card.available_count
                                }}
                              </p>
                              <p>{{product.makeup_tier_text}}</p>
                            </div>
                          {{/if}}
                        </div>

                        <div class="product-action">
                          {{#if product.external_url}}
                            <a
                              href={{product.external_url}}
                              target="_blank"
                              rel="noopener noreferrer"
                              class="btn btn-primary btn-external-buy"
                            >
                              {{dIcon "external-link-alt"}}
                              <span>
                                {{#if product.price_brl}}
                                  Comprar (R$ {{formatBrl product.price_brl}})
                                {{else}}
                                  Comprar
                                {{/if}}
                              </span>
                            </a>
                          {{else if product.is_makeup_card}}
                            {{#if product.purchaseable}}
                              <DButton
                                @action={{fn @controller.buyProduct product.id}}
                                @label="points_mall.shop.buy"
                                class="btn-primary"
                              />
                            {{else if
                              (eq product.purchase_disabled_reason "disabled")
                            }}
                              <DButton
                                @label="points_mall.shop.makeup.off_shelf"
                                @disabled={{true}}
                                class="btn-disabled"
                              />
                            {{else}}
                              <DButton
                                @label="points_mall.shop.makeup.limit_reached"
                                @disabled={{true}}
                                class="btn-disabled"
                              />
                            {{/if}}
                          {{else if
                            (or (eq product.stock -1) (gt product.stock 0))
                          }}
                            <DButton
                              @action={{fn @controller.buyProduct product.id}}
                              @label="points_mall.shop.buy"
                              class="btn-primary"
                            />
                          {{else}}
                            <DButton
                              @label="points_mall.shop.out_of_stock"
                              @disabled={{true}}
                              class="btn-disabled"
                            />
                          {{/if}}
                        </div>
                      </div>
                    {{/each}}
                  </div>
                </section>
              {{/if}}

              <div class="shop-sections">
                {{#each @controller.shopSections as |shopSection|}}
                  <section class="shop-section">
                    <div class="shop-section-head">
                      <div>
                        <h3>{{shopSection.label}}</h3>
                        <p>{{i18n "points_mall.shop.section_tip"}}</p>
                      </div>
                      <span>{{i18n
                          "points_mall.shop.section_count"
                          count=shopSection.count
                        }}</span>
                    </div>

                    <div class="products-grid">
                      {{#each shopSection.products as |product|}}
                        <div
                          class="product-card
                            {{if product.featured 'is-featured'}}"
                        >
                          {{#if product.badge_text}}
                            <span
                              class="product-corner-badge"
                            >{{product.badge_text}}</span>
                          {{else if product.featured}}
                            <span class="product-corner-badge">
                              {{i18n "points_mall.shop.badges.featured"}}
                            </span>
                          {{/if}}

                          {{#if product.image_url}}
                            <div class="product-image">
                              <img
                                src={{product.image_url}}
                                alt={{product.name}}
                              />
                            </div>
                          {{else}}
                            <div class="product-image product-image-placeholder">
                              {{dIcon "gift"}}
                            </div>
                          {{/if}}
                          <div class="product-info">
                            <div class="product-badges">
                              <span class="product-category-badge">
                                {{#if product.category}}
                                  {{product.category}}
                                {{else if (eq product.product_type "physical")}}
                                  {{i18n
                                    "points_mall.shop.filters.category.default_physical"
                                  }}
                                {{else}}
                                  {{i18n
                                    "points_mall.shop.filters.category.default_virtual"
                                  }}
                                {{/if}}
                              </span>
                              <span
                                class="product-type-badge type-{{product.product_type}}"
                              >
                                {{i18n
                                  (concat
                                    "points_mall.shop.type."
                                    product.product_type
                                  )
                                }}
                              </span>
                            </div>

                            <h3>{{product.name}}</h3>
                            <p>{{product.description}}</p>
                            <div class="product-meta">
                              <span class="product-cost">
                                {{#if product.price_brl}}
                                  R$ {{formatBrl product.price_brl}}
                                {{else}}
                                  {{i18n
                                    "points_mall.shop.cost"
                                    points=product.points_cost
                                  }}
                                {{/if}}
                              </span>
                              <span class="product-stock">
                                {{#if (eq product.stock -1)}}
                                  {{i18n "points_mall.shop.unlimited"}}
                                {{else if (gt product.stock 0)}}
                                  {{i18n
                                    "points_mall.shop.stock"
                                    count=product.stock
                                  }}
                                {{else}}
                                  {{i18n "points_mall.shop.out_of_stock"}}
                                {{/if}}
                              </span>
                            </div>
                            <div class="product-stats-row">
                              <span>
                                {{i18n
                                  "points_mall.shop.redeemed_count"
                                  count=product.redeemed_count
                                }}
                              </span>
                            </div>

                            {{#if product.is_makeup_card}}
                              <div class="product-makeup-meta">
                                <p>
                                  {{i18n
                                    "points_mall.shop.makeup.monthly_status"
                                    purchased=product.makeup_card.purchased_count
                                    used=product.makeup_card.used_count
                                    remain=product.makeup_card.available_count
                                  }}
                                </p>
                                <p>{{product.makeup_tier_text}}</p>
                              </div>
                            {{/if}}
                          </div>
                          <div class="product-action">
                            {{#if product.external_url}}
                              <a
                                href={{product.external_url}}
                                target="_blank"
                                rel="noopener noreferrer"
                                class="btn btn-primary btn-external-buy"
                              >
                                {{dIcon "external-link-alt"}}
                                <span>
                                  {{#if product.price_brl}}
                                    Comprar (R$ {{formatBrl product.price_brl}})
                                  {{else}}
                                    Comprar
                                  {{/if}}
                                </span>
                              </a>
                            {{else if product.is_makeup_card}}
                              {{#if product.purchaseable}}
                                <DButton
                                  @action={{fn
                                    @controller.buyProduct
                                    product.id
                                  }}
                                  @label="points_mall.shop.buy"
                                  class="btn-primary"
                                />
                              {{else if
                                (eq product.purchase_disabled_reason "disabled")
                              }}
                                <DButton
                                  @label="points_mall.shop.makeup.off_shelf"
                                  @disabled={{true}}
                                  class="btn-disabled"
                                />
                              {{else}}
                                <DButton
                                  @label="points_mall.shop.makeup.limit_reached"
                                  @disabled={{true}}
                                  class="btn-disabled"
                                />
                              {{/if}}
                            {{else if
                              (or (eq product.stock -1) (gt product.stock 0))
                            }}
                              <DButton
                                @action={{fn @controller.buyProduct product.id}}
                                @label="points_mall.shop.buy"
                                class="btn-primary"
                              />
                            {{else}}
                              <DButton
                                @label="points_mall.shop.out_of_stock"
                                @disabled={{true}}
                                class="btn-disabled"
                              />
                            {{/if}}
                          </div>
                        </div>
                      {{/each}}
                    </div>
                  </section>
                {{/each}}
              </div>
            {{else}}
              <div class="empty-state shop-empty">
                <h3>{{i18n "points_mall.shop.no_match_title"}}</h3>
                <p>{{i18n "points_mall.shop.no_match_tip"}}</p>
              </div>
            {{/if}}
          {{else}}
            <div class="empty-state shop-empty">
              <h3>{{i18n "points_mall.shop.empty_title"}}</h3>
              <p>{{i18n "points_mall.shop.empty_tip"}}</p>
            </div>
          {{/if}}
        </div>
      {{/if}}



      {{#if (eq @controller.activeTab "orders")}}
        <div class="points-mall-orders">
          <div class="orders-header">
            <div class="orders-title-wrap">
              <div class="orders-title-icon">{{dIcon "clock-rotate-left"}}</div>
              <div>
                <h2>{{i18n "points_mall.orders.title"}}</h2>
                <p>{{i18n "points_mall.orders.subtitle"}}</p>
              </div>
            </div>

            <div class="orders-summary">
              <article class="orders-summary-item">
                <span>{{i18n "points_mall.orders.summary.all"}}</span>
                <strong>{{@controller.orderSummary.all}}</strong>
              </article>
              <article class="orders-summary-item">
                <span>{{i18n "points_mall.orders.summary.physical"}}</span>
                <strong>{{@controller.orderSummary.physical}}</strong>
              </article>
              <article class="orders-summary-item">
                <span>{{i18n "points_mall.orders.summary.virtual"}}</span>
                <strong>{{@controller.orderSummary.virtual}}</strong>
              </article>
            </div>
          </div>

          <div class="orders-hint-banner">
            {{dIcon "circle-info"}}
            <span>{{i18n "points_mall.orders.tip_banner"}}</span>
          </div>

          <div class="orders-type-filters">
            {{#each @controller.orderTypeFilters as |filter|}}
              <button
                type="button"
                class="orders-type-filter
                  {{if (eq @controller.orderTypeFilter filter) 'active'}}"
                aria-pressed={{if
                  (eq @controller.orderTypeFilter filter)
                  "true"
                  "false"
                }}
                {{on "click" (fn @controller.setOrderTypeFilter filter)}}
              >
                {{i18n (concat "points_mall.orders.filters." filter)}}
              </button>
            {{/each}}
          </div>

          {{#if @controller.hasFilteredOrders}}
            <div class="orders-list">
              {{#each @controller.paginatedOrders as |order|}}
                <div class="order-card status-{{order.status}}">
                  <div class="order-card-header">
                    <div class="order-product-thumb">
                      {{#if order.product.image_url}}
                        <img
                          src={{order.product.image_url}}
                          alt={{order.product.name}}
                        />
                      {{else if (eq order.display_product_type "physical")}}
                        {{dIcon "box"}}
                      {{else}}
                        {{dIcon "bolt"}}
                      {{/if}}
                    </div>

                    <div class="order-header-info">
                      <div class="order-title-row">
                        <h3>{{order.product.name}}</h3>
                        <span class="order-id-tag">#{{order.id}}</span>
                      </div>
                      <div class="order-meta-chips">
                        <span
                          class="order-product-type type-{{order.display_product_type}}"
                        >
                          {{i18n
                            (concat
                              "points_mall.orders.types."
                              order.display_product_type
                            )
                          }}
                        </span>
                        <span class="order-cost">
                          {{order.points_spent}} pts
                        </span>
                        <span class="order-date">
                          {{dIcon "clock"}} {{formatDateFixed order.created_at}}
                        </span>
                      </div>
                    </div>

                    <div class="order-status-badge-wrap">
                      <span class="order-status status-{{order.status}}">
                        {{i18n
                          (concat "points_mall.orders.status." order.status)
                        }}
                      </span>
                    </div>
                  </div>

                  {{! LINHA DO TEMPO GRÁFICA DE STATUS (STEPPER) }}
                  <div class="order-stepper-wrap">
                    <div class="order-stepper">
                      {{! Step 1: Recebido }}
                      <div class="stepper-step step-done">
                        <div class="stepper-circle">
                          {{dIcon "check"}}
                        </div>
                        <span class="stepper-label">Pedido Recebido</span>
                      </div>
                      <div class="stepper-line {{if (or (eq order.status "pending") (eq order.status "shipped") (eq order.status "completed") (eq order.status "refunded")) "line-active"}}"></div>

                      {{! Step 2: Em Processamento / Enviado }}
                      <div class="stepper-step {{if (or (eq order.status "shipped") (eq order.status "completed")) "step-done" (if (eq order.status "pending") "step-current" "")}}">
                        <div class="stepper-circle">
                          {{#if (or (eq order.status "shipped") (eq order.status "completed"))}}
                            {{dIcon "check"}}
                          {{else if (eq order.status "pending")}}
                            {{dIcon "hourglass-half"}}
                          {{else if (eq order.status "refunded")}}
                            {{dIcon "rotate-left"}}
                          {{else}}
                            {{dIcon "circle"}}
                          {{/if}}
                        </div>
                        <span class="stepper-label">
                          {{if (eq order.status "shipped") "Enviado" (if (eq order.status "refunded") "Estornado" "Processando")}}
                        </span>
                      </div>
                      <div class="stepper-line {{if (or (eq order.status "completed") (eq order.status "refunded")) "line-active"}}"></div>

                      {{! Step 3: Concluído / Reembolsado }}
                      <div class="stepper-step {{if (eq order.status "completed") "step-done" (if (eq order.status "refunded") "step-refunded" (if (eq order.status "canceled") "step-canceled" ""))}}">
                        <div class="stepper-circle">
                          {{#if (eq order.status "completed")}}
                            {{dIcon "circle-check"}}
                          {{else if (eq order.status "refunded")}}
                            {{dIcon "arrow-rotate-left"}}
                          {{else if (eq order.status "canceled")}}
                            {{dIcon "xmark"}}
                          {{else}}
                            {{dIcon "circle"}}
                          {{/if}}
                        </div>
                        <span class="stepper-label">
                          {{if (eq order.status "completed") "Entregue & Concluído" (if (eq order.status "refunded") "Reembolsado" (if (eq order.status "canceled") "Cancelado" "Conclusão"))}}
                        </span>
                      </div>
                    </div>
                  </div>

                  {{! DETALHES DE ENTREGA & BOTÃO DE COPIAR COM 1 CLIQUE }}
                  {{#if (or order.shipping_info order.notes)}}
                    <div class="order-details-card">
                      {{#if order.shipping_info}}
                        <div class="order-detail-block">
                          <strong>{{dIcon "location-dot"}} {{i18n "points_mall.orders.shipping_info"}}:</strong>
                          <p>{{order.shipping_info}}</p>
                        </div>
                      {{/if}}

                      {{#if order.notes}}
                        <div class="order-detail-block">
                          <strong>{{dIcon "clipboard-list"}} {{i18n "points_mall.orders.notes"}}:</strong>
                          <p>{{order.notes}}</p>
                        </div>
                      {{/if}}

                      <div class="order-copy-action">
                        <button
                          type="button"
                          class="btn btn-default btn-copy-details {{if (eq @controller.copiedOrderId order.id) "copied"}}"
                          {{on "click" (fn @controller.copyOrderDetails order)}}
                        >
                          {{#if (eq @controller.copiedOrderId order.id)}}
                            {{dIcon "check"}} <span>Copiado!</span>
                          {{else}}
                            {{dIcon "copy"}} <span>Copiar Dados de Entrega</span>
                          {{/if}}
                        </button>
                      </div>
                    </div>
                  {{/if}}
                </div>
              {{/each}}
            </div>

            {{#if @controller.hasMultipleOrderPages}}
              <div class="orders-pagination">
                <button
                  type="button"
                  class="btn btn-default btn-pagination-prev"
                  disabled={{not @controller.canPrevOrdersPage}}
                  {{on "click" @controller.prevOrdersPage}}
                >
                  {{dIcon "chevron-left"}} <span>Anterior</span>
                </button>

                <div class="pagination-info">
                  Página <strong>{{@controller.ordersPage}}</strong> de <strong>{{@controller.ordersTotalPages}}</strong>
                </div>

                <button
                  type="button"
                  class="btn btn-default btn-pagination-next"
                  disabled={{not @controller.canNextOrdersPage}}
                  {{on "click" @controller.nextOrdersPage}}
                >
                  <span>Próxima</span> {{dIcon "chevron-right"}}
                </button>
              </div>
            {{/if}}
          {{else}}
            <div class="empty-state orders-empty">
              <div class="orders-empty-icon">{{dIcon "box"}}</div>
              <h3>{{i18n "points_mall.orders.empty"}}</h3>
              <p>{{i18n "points_mall.orders.empty_hint"}}</p>
              <DButton
                @icon="gift"
                @label="points_mall.orders.go_shop"
                @action={{@controller.goToShop}}
                class="btn-primary"
              />
            </div>
          {{/if}}

          <div class="points-mall-addresses">
            <div class="points-mall-addresses-header">
              <h3>{{i18n "points_mall.addresses.title"}}</h3>
              <button
                type="button"
                class="btn btn-primary btn-small"
                {{on "click" @controller.openCreateAddressEditor}}
                disabled={{if @controller.canCreateMoreAddresses false true}}
              >
                {{i18n "points_mall.addresses.new"}}
              </button>
            </div>

            <p class="points-mall-addresses-limit">
              {{i18n
                "points_mall.addresses.limit_hint"
                count=3
                current=@controller.addresses.length
              }}
            </p>

            {{#if @controller.addresses.length}}
              <div class="points-mall-address-list">
                {{#each @controller.addresses as |address|}}
                  <div class="points-mall-address-card">
                    <div class="points-mall-address-main">
                      <div class="points-mall-address-top">
                        <span
                          class="points-mall-address-recipient"
                        >{{address.recipient_name}}</span>
                        <span
                          class="points-mall-address-phone"
                        >{{address.phone}}</span>
                        {{#if address.is_default}}
                          <span class="points-mall-address-default">
                            {{i18n "points_mall.addresses.default_badge"}}
                          </span>
                        {{/if}}
                      </div>
                      <p
                        class="points-mall-address-line"
                      >{{address.address_line}}</p>
                    </div>
                    <div class="points-mall-address-actions">
                      {{#unless address.is_default}}
                        <DButton
                          @label="points_mall.addresses.set_default"
                          @action={{fn
                            @controller.setDefaultAddress
                            address.id
                          }}
                          class="btn-flat"
                        />
                      {{/unless}}
                      <DButton
                        @label="points_mall.addresses.edit"
                        @action={{fn @controller.editAddress address}}
                        class="btn-flat"
                      />
                      <DButton
                        @label="points_mall.addresses.delete"
                        @action={{fn @controller.deleteAddress address.id}}
                        class="btn-danger btn-flat"
                      />
                    </div>
                  </div>
                {{/each}}
              </div>
            {{else}}
              <div class="points-mall-address-empty">
                {{i18n "points_mall.addresses.empty"}}
              </div>
            {{/if}}

            {{#if @controller.showAddressEditor}}
              <div class="points-mall-address-editor">
                <h4>
                  {{#if @controller.isEditingAddress}}
                    {{i18n "points_mall.addresses.edit"}}
                  {{else}}
                    {{i18n "points_mall.addresses.new"}}
                  {{/if}}
                </h4>

                <div class="points-mall-address-form-grid">
                  <div class="points-mall-field">
                    <label>{{i18n
                        "points_mall.addresses.recipient_name"
                      }}</label>
                    <Input
                      @value={{@controller.addressEditorForm.recipient_name}}
                      placeholder={{i18n
                        "points_mall.addresses.recipient_placeholder"
                      }}
                      {{on
                        "input"
                        (fn
                          @controller.updateAddressEditorField "recipient_name"
                        )
                      }}
                    />
                  </div>
                  <div class="points-mall-field">
                    <label>{{i18n "points_mall.addresses.phone"}}</label>
                    <Input
                      @value={{@controller.addressEditorForm.phone}}
                      placeholder={{i18n
                        "points_mall.addresses.phone_placeholder"
                      }}
                      {{on
                        "input"
                        (fn @controller.updateAddressEditorField "phone")
                      }}
                    />
                  </div>
                  <div class="points-mall-field --full">
                    <label>{{i18n "points_mall.addresses.address_line"}}</label>
                    <Input
                      @value={{@controller.addressEditorForm.address_line}}
                      placeholder={{i18n
                        "points_mall.addresses.address_placeholder"
                      }}
                      {{on
                        "input"
                        (fn @controller.updateAddressEditorField "address_line")
                      }}
                    />
                  </div>
                  <label class="points-mall-checkbox --full">
                    <Input
                      @type="checkbox"
                      @checked={{@controller.addressEditorForm.is_default}}
                      {{on "change" @controller.toggleAddressEditorDefault}}
                    />
                    <span>{{i18n "points_mall.addresses.set_as_default"}}</span>
                  </label>
                </div>

                <div class="points-mall-address-editor-actions">
                  <button
                    type="button"
                    class="btn"
                    {{on "click" @controller.cancelAddressEditor}}
                  >
                    {{i18n "points_mall.checkout.cancel"}}
                  </button>
                  <button
                    type="button"
                    class="btn btn-primary"
                    {{on "click" @controller.saveAddressEditor}}
                    disabled={{@controller.isSavingAddress}}
                  >
                    {{#if @controller.isEditingAddress}}
                      {{i18n "points_mall.addresses.update"}}
                    {{else}}
                      {{i18n "points_mall.addresses.save"}}
                    {{/if}}
                  </button>
                </div>
              </div>
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#if (eq @controller.activeTab "ledger")}}
        <div class="points-mall-ledger">
          <div class="ledger-header">
            <div class="ledger-title-wrap">
              <div class="ledger-title-icon">{{dIcon "wallet"}}</div>
              <div>
                <h2>{{i18n "points_mall.points.title"}}</h2>
                <p>{{i18n "points_mall.points.subtitle"}}</p>
              </div>
            </div>
            <div class="ledger-balance-card">
              <span>{{i18n "points_mall.points.current_points"}}</span>
              <strong>{{@controller.currentUser.points_balance}}</strong>
            </div>
          </div>

          <div class="ledger-summary-grid">
            <article class="ledger-summary-card income">
              <span>{{i18n "points_mall.points.summary.income"}}</span>
              <strong>{{@controller.pointsSummary.income_count}}</strong>
            </article>
            <article class="ledger-summary-card expense">
              <span>{{i18n "points_mall.points.summary.expense"}}</span>
              <strong>{{@controller.pointsSummary.expense_count}}</strong>
            </article>
          </div>

          <div class="ledger-filter-row">
            {{#each @controller.pointsFilters as |filter|}}
              <button
                type="button"
                class="ledger-filter-item
                  {{if (eq @controller.pointsFilter filter) 'active'}}"
                aria-pressed={{if
                  (eq @controller.pointsFilter filter)
                  "true"
                  "false"
                }}
                {{on "click" (fn @controller.setPointsFilter filter)}}
              >
                {{i18n (concat "points_mall.points.filters." filter)}}
              </button>
            {{/each}}
          </div>

          {{#if @controller.hasLedgerEvents}}
            <div class="ledger-event-list">
              {{#each @controller.paginatedLedgerEvents as |event|}}
                <article class="ledger-event-item">
                  <div class="ledger-event-main">
                    <span class="ledger-event-mark {{event.direction}}">
                      {{#if (eq event.direction "income")}}
                        {{dIcon "plus"}}
                      {{else}}
                        {{dIcon "minus"}}
                      {{/if}}
                    </span>
                    <div>
                      <strong>{{event.description}}</strong>
                      <p>{{formatDateFixed event.created_at}}</p>
                    </div>
                  </div>
                  <strong class="ledger-event-points {{event.direction}}">
                    {{#if
                      (eq event.direction "income")
                    }}+{{/if}}{{event.points}} pts
                  </strong>
                </article>
              {{/each}}
            </div>

            {{#if (gt @controller.totalLedgerPages 1)}}
              <div class="ledger-pagination">
                <button
                  type="button"
                  class="btn btn-default btn-small"
                  disabled={{eq @controller.ledgerPage 1}}
                  {{on "click" @controller.prevLedgerPage}}
                >
                  {{dIcon "chevron-left"}} Anterior
                </button>

                <span class="ledger-page-indicator">
                  Página {{@controller.ledgerPage}} de {{@controller.totalLedgerPages}}
                </span>

                <button
                  type="button"
                  class="btn btn-default btn-small"
                  disabled={{eq @controller.ledgerPage @controller.totalLedgerPages}}
                  {{on "click" @controller.nextLedgerPage}}
                >
                  Próxima {{dIcon "chevron-right"}}
                </button>
              </div>
            {{/if}}
          {{else}}
            <div class="ledger-empty">
              {{i18n "points_mall.points.empty"}}
            </div>
          {{/if}}
        </div>
      {{/if}}
    </div>

    {{#if @controller.purchaseModalOpen}}
      <div class="points-mall-modal-backdrop">
        <button
          type="button"
          class="points-mall-modal-dismiss-surface"
          aria-label={{i18n "close"}}
          {{on "click" @controller.closePurchaseModal}}
        ></button>
        <div class="points-mall-modal" role="dialog" aria-modal="true">
          <div class="points-mall-modal-header">
            <h3>
              {{i18n
                @controller.checkoutTitleKey
                product=@controller.checkoutProduct.name
              }}
            </h3>
          </div>

          <div class="points-mall-modal-body">
            {{#if (eq @controller.checkoutStep "virtual")}}
              <p>
                {{i18n
                  "points_mall.checkout.virtual_message"
                  product=@controller.checkoutProduct.name
                }}
              </p>
              <p class="points-mall-modal-tip">{{i18n
                  "points_mall.checkout.virtual_tip"
                }}</p>
            {{/if}}

            {{#if (eq @controller.checkoutStep "physical-confirm")}}
              <p class="points-mall-modal-tip">{{i18n
                  "points_mall.checkout.use_default_address"
                }}</p>
              {{#if @controller.selectedCheckoutAddress}}
                <div class="points-mall-checkout-address-preview">
                  <p>
                    <strong
                    >{{@controller.selectedCheckoutAddress.recipient_name}}</strong>
                    {{@controller.selectedCheckoutAddress.phone}}
                  </p>
                  <p>{{@controller.selectedCheckoutAddress.address_line}}</p>
                </div>
              {{/if}}
            {{/if}}

            {{#if (eq @controller.checkoutStep "physical-select")}}
              <p class="points-mall-modal-tip">{{i18n
                  "points_mall.checkout.choose_address"
                }}</p>
              <div class="points-mall-checkout-address-list">
                {{#each @controller.addresses as |address|}}
                  <label class="points-mall-checkout-address-item">
                    <Input
                      @type="radio"
                      name="checkout-address"
                      @checked={{eq
                        @controller.checkoutSelectedAddressId
                        address.id
                      }}
                      {{on
                        "change"
                        (fn @controller.setCheckoutAddress address.id)
                      }}
                    />
                    <span>
                      <strong>{{address.recipient_name}}</strong>
                      {{address.phone}}
                      {{#if address.is_default}}
                        <em>{{i18n "points_mall.addresses.default_badge"}}</em>
                      {{/if}}
                      <small>{{address.address_line}}</small>
                    </span>
                  </label>
                {{/each}}
              </div>

              <div class="points-mall-checkout-inline-actions">
                <button
                  type="button"
                  class="btn"
                  {{on "click" @controller.useNewAddressInCheckout}}
                  disabled={{if @controller.canCreateMoreAddresses false true}}
                >
                  {{i18n "points_mall.checkout.add_new_address"}}
                </button>
              </div>
            {{/if}}

            {{#if (eq @controller.checkoutStep "physical-form")}}
              <div class="points-mall-address-form-grid">
                <div class="points-mall-field --full">
                  <label>{{i18n "points_mall.addresses.recipient_name"}}</label>
                  <Input
                    @value={{@controller.checkoutAddressForm.recipient_name}}
                    placeholder={{i18n
                      "points_mall.addresses.recipient_placeholder"
                    }}
                    {{on
                      "input"
                      (fn
                        @controller.updateCheckoutAddressField "recipient_name"
                      )
                    }}
                  />
                </div>
                <div class="points-mall-field --full">
                  <label>{{i18n "points_mall.addresses.phone"}}</label>
                  <Input
                    @value={{@controller.checkoutAddressForm.phone}}
                    placeholder={{i18n
                      "points_mall.addresses.phone_placeholder"
                    }}
                    {{on
                      "input"
                      (fn @controller.updateCheckoutAddressField "phone")
                    }}
                  />
                </div>
                <div class="points-mall-field --full">
                  <label>{{i18n "points_mall.addresses.address_line"}}</label>
                  <Input
                    @value={{@controller.checkoutAddressForm.address_line}}
                    placeholder={{i18n
                      "points_mall.addresses.address_placeholder"
                    }}
                    {{on
                      "input"
                      (fn @controller.updateCheckoutAddressField "address_line")
                    }}
                  />
                </div>
                <label class="points-mall-checkbox --full">
                  <Input
                    @type="checkbox"
                    @checked={{@controller.checkoutAddressForm.is_default}}
                    {{on "change" @controller.toggleCheckoutAddressDefault}}
                  />
                  <span>{{i18n "points_mall.addresses.set_as_default"}}</span>
                </label>
              </div>

              {{#if @controller.addresses.length}}
                <div class="points-mall-checkout-inline-actions">
                  <button
                    type="button"
                    class="btn btn-flat"
                    {{on "click" @controller.backToAddressSelect}}
                  >
                    {{i18n "points_mall.checkout.back_to_address_list"}}
                  </button>
                </div>
              {{/if}}
            {{/if}}
          </div>

          <div class="points-mall-modal-footer">
            <button
              type="button"
              class="btn"
              {{on "click" @controller.closePurchaseModal}}
            >
              {{i18n "points_mall.checkout.cancel"}}
            </button>
            <button
              type="button"
              class="btn btn-primary"
              {{on "click" @controller.submitCheckout}}
              disabled={{@controller.isSubmittingCheckout}}
            >
              {{i18n @controller.checkoutSubmitKey}}
            </button>
          </div>
        </div>
      </div>
    {{/if}}
  </div>
</template>
