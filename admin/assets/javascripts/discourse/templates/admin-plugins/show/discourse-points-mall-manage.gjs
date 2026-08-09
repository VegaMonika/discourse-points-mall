import { Input, Textarea } from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-detail points-mall-admin">
    <h1>{{i18n "points_mall.admin.manage"}}</h1>

    <section class="points-mall-admin-section">
      <div class="points-mall-admin-overview-head">
        <div>
          <h2>{{i18n "points_mall.admin.overview.title"}}</h2>
          <p>{{i18n "points_mall.admin.overview.help"}}</p>
        </div>
        <DButton
          @icon="rotate-right"
          @label="points_mall.admin.checkins.refresh"
          @action={{@controller.reloadCheckinSummary}}
          class="btn-default"
        />
      </div>

      <div class="points-mall-admin-overview-grid">
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.products"}}</h3>
          <p>{{@controller.model.dashboardStats.products}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.total_orders"}}</h3>
          <p>{{@controller.model.dashboardStats.totalOrders}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.physical_orders"}}</h3>
          <p>{{@controller.model.dashboardStats.physicalOrders}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.virtual_orders"}}</h3>
          <p>{{@controller.model.dashboardStats.virtualOrders}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.pending_orders"}}</h3>
          <p>{{@controller.model.dashboardStats.pendingOrders}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.overview.cards.today_checkins"}}</h3>
          <p>{{@controller.model.dashboardStats.todayCheckins}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n
              "points_mall.admin.overview.cards.today_checkin_points"
            }}</h3>
          <p>{{@controller.model.dashboardStats.todayCheckinPoints}}</p>
        </article>
      </div>
    </section>

    <section class="points-mall-admin-section">
      <h2>{{i18n "points_mall.admin.checkins.title"}}</h2>
      <p>{{i18n "points_mall.admin.checkins.help"}}</p>

      <div
        class="points-mall-admin-overview-grid points-mall-admin-overview-grid-checkin"
      >
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.checkins.cards.total_checkins"}}</h3>
          <p>{{@controller.model.checkinSummary.total_checkins}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.checkins.cards.total_points"}}</h3>
          <p>{{@controller.model.checkinSummary.total_points}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.checkins.cards.today_checkins"}}</h3>
          <p>{{@controller.model.checkinSummary.today_checkins}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.checkins.cards.today_points"}}</h3>
          <p>{{@controller.model.checkinSummary.today_points}}</p>
        </article>
        <article class="points-mall-admin-stat-card">
          <h3>{{i18n "points_mall.admin.checkins.cards.active_users_7d"}}</h3>
          <p>{{@controller.model.checkinSummary.active_users_7d}}</p>
        </article>
      </div>

      <div class="points-mall-admin-subgrid">
        <article class="points-mall-admin-card">
          <h3>{{i18n "points_mall.admin.checkins.trend_title"}}</h3>
          <table class="d-admin-table points-mall-admin-table">
            <thead>
              <tr>
                <th>{{i18n "points_mall.admin.checkins.fields.date"}}</th>
                <th>{{i18n "points_mall.admin.checkins.fields.checkins"}}</th>
                <th>{{i18n "points_mall.admin.checkins.fields.points"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @controller.model.checkinTrend as |day|}}
                <tr>
                  <td>{{dFormatDate day.date}}</td>
                  <td>{{day.checkins}}</td>
                  <td>{{day.points}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </article>

        <article class="points-mall-admin-card">
          <h3>{{i18n "points_mall.admin.checkins.top_users_title"}}</h3>
          <table class="d-admin-table points-mall-admin-table">
            <thead>
              <tr>
                <th>{{i18n "points_mall.admin.checkins.fields.user"}}</th>
                <th>{{i18n "points_mall.admin.checkins.fields.checkins"}}</th>
                <th>{{i18n "points_mall.admin.checkins.fields.points"}}</th>
                <th>{{i18n
                    "points_mall.admin.checkins.fields.current_streak"
                  }}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @controller.model.checkinTopUsers as |row|}}
                <tr>
                  <td>{{row.username}}</td>
                  <td>{{row.checkins}}</td>
                  <td>{{row.points}}</td>
                  <td>{{row.current_streak}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </article>
      </div>

      <article class="points-mall-admin-card">
        <h3>{{i18n "points_mall.admin.checkins.recent_title"}}</h3>
        <table class="d-admin-table points-mall-admin-table">
          <thead>
            <tr>
              <th>{{i18n "points_mall.admin.checkins.fields.user"}}</th>
              <th>{{i18n "points_mall.admin.checkins.fields.date"}}</th>
              <th>{{i18n "points_mall.admin.checkins.fields.points"}}</th>
              <th>{{i18n
                  "points_mall.admin.checkins.fields.current_streak"
                }}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.model.recentCheckins as |checkin|}}
              <tr>
                <td>{{checkin.username}}</td>
                <td>{{dFormatDate checkin.checkin_date}}</td>
                <td>{{checkin.points_earned}}</td>
                <td>{{if checkin.streak_days checkin.streak_days "-"}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </article>
    </section>

    <section class="points-mall-admin-section">
      <h2>{{i18n "points_mall.admin.products.title"}}</h2>
      <p>{{i18n "points_mall.admin.products.help"}}</p>

      <article class="points-mall-admin-card">
        <h3>{{i18n "points_mall.admin.products.makeup.title"}}</h3>
        <p>{{i18n "points_mall.admin.products.makeup.help"}}</p>
        <div class="points-mall-admin-makeup-config">
          <div class="points-mall-admin-makeup-field">
            <label>{{i18n "points_mall.admin.products.makeup.tier_1"}}</label>
            <Input
              @value={{@controller.model.makeupConfig.tier_1}}
              @type="number"
              class="points-mall-admin-input --number"
              {{on "input" (fn @controller.setMakeupTier "tier_1")}}
            />
          </div>
          <div class="points-mall-admin-makeup-field">
            <label>{{i18n "points_mall.admin.products.makeup.tier_2"}}</label>
            <Input
              @value={{@controller.model.makeupConfig.tier_2}}
              @type="number"
              class="points-mall-admin-input --number"
              {{on "input" (fn @controller.setMakeupTier "tier_2")}}
            />
          </div>
          <div class="points-mall-admin-makeup-field">
            <label>{{i18n "points_mall.admin.products.makeup.tier_3"}}</label>
            <Input
              @value={{@controller.model.makeupConfig.tier_3}}
              @type="number"
              class="points-mall-admin-input --number"
              {{on "input" (fn @controller.setMakeupTier "tier_3")}}
            />
          </div>
          <DButton
            @icon="save"
            @label="points_mall.admin.products.makeup.save"
            @action={{@controller.saveMakeupConfig}}
            class="btn-primary"
          />
        </div>
        <p>
          {{i18n
            "points_mall.admin.products.makeup.tiers"
            first=@controller.model.makeupConfig.tier_1
            second=@controller.model.makeupConfig.tier_2
            third=@controller.model.makeupConfig.tier_3
          }}
        </p>
        <p>{{i18n "points_mall.admin.products.makeup.save_help"}}</p>
        {{#unless @controller.model.makeupConfig.feature_ready}}
          <p>{{i18n "points_mall.admin.products.makeup.migration_hint"}}</p>
        {{/unless}}
      </article>

      <div class="points-mall-admin-table-wrap">
        <table class="d-admin-table points-mall-admin-table">
          <thead>
            <tr>
              <th>{{i18n "points_mall.admin.products.fields.name"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.cost"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.stock"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.type"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.category"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.badge_text"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.sort_order"}}</th>
              <th>{{i18n
                  "points_mall.admin.products.fields.redeemed_count"
                }}</th>
              <th>{{i18n "points_mall.admin.products.fields.featured"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.image_url"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.enabled"}}</th>
              <th>{{i18n "points_mall.admin.products.fields.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.model.products as |product|}}
              <tr class={{if product.is_makeup_card "is-system-product"}}>
                <td>
                  <Input
                    @value={{product.name}}
                    class="points-mall-admin-input"
                  />
                  {{#if product.is_makeup_card}}
                    <span class="points-mall-admin-system-badge">
                      {{i18n "points_mall.admin.products.makeup.badge"}}
                    </span>
                  {{/if}}
                </td>
                <td>
                  <Input
                    @value={{product.points_cost}}
                    @type="number"
                    class="points-mall-admin-input --number"
                    disabled={{product.is_makeup_card}}
                  />
                  {{#if product.is_makeup_card}}
                    <p class="points-mall-admin-row-tip">
                      {{i18n
                        "points_mall.admin.products.makeup.controlled_cost_hint"
                      }}
                    </p>
                  {{/if}}
                </td>
                <td>
                  <Input
                    @value={{product.stock}}
                    @type="number"
                    class="points-mall-admin-input --number"
                    disabled={{product.is_makeup_card}}
                  />
                </td>
                <td>
                  <select
                    class="points-mall-admin-select"
                    {{on "change" (fn @controller.setProductType product)}}
                    disabled={{product.is_makeup_card}}
                  >
                    {{#each @controller.model.productTypes as |type|}}
                      <option
                        selected={{eq product.product_type type}}
                        value={{type}}
                      >{{type}}</option>
                    {{/each}}
                  </select>
                </td>
                <td>
                  <Input
                    @value={{product.category}}
                    class="points-mall-admin-input"
                    placeholder={{i18n
                      "points_mall.admin.products.fields.category"
                    }}
                  />
                </td>
                <td>
                  <Input
                    @value={{product.badge_text}}
                    class="points-mall-admin-input --tag"
                    placeholder={{i18n
                      "points_mall.admin.products.fields.badge_text"
                    }}
                  />
                </td>
                <td>
                  <Input
                    @value={{product.sort_order}}
                    @type="number"
                    class="points-mall-admin-input --number"
                  />
                </td>
                <td>
                  <span
                    class="points-mall-admin-metric"
                  >{{product.redeemed_count}}</span>
                </td>
                <td>
                  <Input
                    @type="checkbox"
                    @checked={{product.featured}}
                    {{on "change" (fn @controller.setProductFeatured product)}}
                  />
                </td>
                <td>
                  <Input
                    @value={{product.image_url}}
                    class="points-mall-admin-input --wide"
                  />
                </td>
                <td>
                  <Input
                    @type="checkbox"
                    @checked={{product.enabled}}
                    {{on "change" (fn @controller.setProductEnabled product)}}
                  />
                </td>
                <td>
                  <DButton
                    @icon="save"
                    @action={{fn @controller.saveProduct product}}
                    class="btn-primary"
                  />
                  {{#unless product.is_makeup_card}}
                    <DButton
                      @icon="trash-can"
                      @action={{fn @controller.deleteProduct product}}
                      class="btn-danger"
                    />
                  {{/unless}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </div>

      <div class="points-mall-admin-create">
        <h3>{{i18n "points_mall.admin.products.new"}}</h3>
        <div class="points-mall-admin-row">
          <Input
            @value={{@controller.model.newProduct.name}}
            placeholder={{i18n "points_mall.admin.products.fields.name"}}
            class="points-mall-admin-input"
          />
          <Input
            @value={{@controller.model.newProduct.points_cost}}
            @type="number"
            placeholder={{i18n "points_mall.admin.products.fields.cost"}}
            class="points-mall-admin-input --number"
          />
          <Input
            @value={{@controller.model.newProduct.stock}}
            @type="number"
            placeholder={{i18n "points_mall.admin.products.fields.stock"}}
            class="points-mall-admin-input --number"
          />
          <select
            class="points-mall-admin-select"
            {{on
              "change"
              (fn @controller.setProductType @controller.model.newProduct)
            }}
          >
            {{#each @controller.model.productTypes as |type|}}
              <option
                selected={{eq @controller.model.newProduct.product_type type}}
                value={{type}}
              >{{type}}</option>
            {{/each}}
          </select>
          <Input
            @value={{@controller.model.newProduct.category}}
            placeholder={{i18n "points_mall.admin.products.fields.category"}}
            class="points-mall-admin-input"
          />
          <Input
            @value={{@controller.model.newProduct.badge_text}}
            placeholder={{i18n "points_mall.admin.products.fields.badge_text"}}
            class="points-mall-admin-input --tag"
          />
          <Input
            @value={{@controller.model.newProduct.sort_order}}
            @type="number"
            placeholder={{i18n "points_mall.admin.products.fields.sort_order"}}
            class="points-mall-admin-input --number"
          />
          <label>
            <Input
              @type="checkbox"
              @checked={{@controller.model.newProduct.featured}}
              {{on
                "change"
                (fn @controller.setProductFeatured @controller.model.newProduct)
              }}
            />
            {{i18n "points_mall.admin.products.fields.featured"}}
          </label>
          <label>
            <Input
              @type="checkbox"
              @checked={{@controller.model.newProduct.enabled}}
              {{on
                "change"
                (fn @controller.setProductEnabled @controller.model.newProduct)
              }}
            />
            {{i18n "points_mall.admin.products.fields.enabled"}}
          </label>
          <DButton
            @label="points_mall.admin.actions.add"
            @icon="plus"
            @action={{@controller.createProduct}}
            class="btn-primary"
          />
        </div>
        <div class="points-mall-admin-row">
          <Input
            @value={{@controller.model.newProduct.description}}
            placeholder={{i18n "points_mall.admin.products.fields.description"}}
            class="points-mall-admin-input --wide"
          />
          <Input
            @value={{@controller.model.newProduct.image_url}}
            placeholder={{i18n "points_mall.admin.products.fields.image_url"}}
            class="points-mall-admin-input --wide"
          />
        </div>
        <p class="points-mall-admin-row-tip">
          {{i18n "points_mall.admin.products.badge_tip"}}
        </p>
        <p class="points-mall-admin-row-tip">
          {{i18n "points_mall.admin.products.makeup.create_hint"}}
        </p>
      </div>
    </section>

    <section class="points-mall-admin-section">
      <div class="points-mall-admin-orders-head">
        <div>
          <h2>{{i18n "points_mall.admin.orders.title"}}</h2>
          <p>{{i18n "points_mall.admin.orders.help"}}</p>
        </div>

        <div class="points-mall-admin-order-filters">
          <div class="points-mall-admin-order-filter">
            <span class="points-mall-admin-filter-label">
              {{i18n "points_mall.admin.orders.filters.type_label"}}
            </span>
            <div class="points-mall-admin-chip-row">
              {{#each @controller.model.orderTypes as |type|}}
                <button
                  type="button"
                  class="points-mall-admin-chip
                    {{if (eq @controller.adminOrderTypeFilter type) 'active'}}"
                  {{on "click" (fn @controller.setAdminOrderTypeFilter type)}}
                >
                  {{i18n
                    (concat "points_mall.admin.orders.filters.type." type)
                  }}
                </button>
              {{/each}}
            </div>
          </div>

          <div class="points-mall-admin-order-filter">
            <label
              class="points-mall-admin-filter-label"
              for="pm-admin-order-status-filter"
            >
              {{i18n "points_mall.admin.orders.filters.status_label"}}
            </label>
            <select
              id="pm-admin-order-status-filter"
              class="points-mall-admin-select"
              {{on "change" @controller.setAdminOrderStatusFilter}}
            >
              {{#each @controller.adminOrderStatuses as |status|}}
                <option
                  selected={{eq @controller.adminOrderStatusFilter status}}
                  value={{status}}
                >
                  {{i18n
                    (concat "points_mall.admin.orders.filters.status." status)
                  }}
                </option>
              {{/each}}
            </select>
          </div>
        </div>
      </div>

      {{#if @controller.filteredAdminOrders.length}}
        <div class="points-mall-admin-order-list">
          {{#each @controller.filteredAdminOrders as |order|}}
            <article class="points-mall-admin-order-card">
              <header class="points-mall-admin-order-head">
                <div class="points-mall-admin-order-id">
                  #{{order.id}}
                </div>
                <span
                  class="points-mall-admin-order-type type-{{order.display_product_type}}"
                >
                  {{i18n
                    (concat
                      "points_mall.orders.types." order.display_product_type
                    )
                  }}
                </span>
                <span
                  class="points-mall-admin-order-status status-{{order.status}}"
                >
                  {{i18n (concat "points_mall.orders.status." order.status)}}
                </span>
                <span class="points-mall-admin-order-date">{{dFormatDate
                    order.created_at
                  }}</span>
              </header>

              <div class="points-mall-admin-order-main">
                <div class="points-mall-admin-order-user">
                  <div class="points-mall-admin-order-avatar">
                    {{#if order.avatar_url}}
                      <img src={{order.avatar_url}} alt={{order.username}} />
                    {{else}}
                      {{dIcon "user"}}
                    {{/if}}
                  </div>
                  <div class="points-mall-admin-order-userinfo">
                    <strong>{{order.username}}</strong>
                    <div class="points-mall-admin-order-usermeta">
                      <span
                        class="points-mall-admin-role-badge
                          {{order.user_role_class}}"
                      >
                        {{i18n order.user_role_label_key}}
                      </span>
                      <span class="points-mall-admin-order-trust">
                        {{i18n
                          "points_mall.admin.orders.trust_level"
                          level=order.trust_level
                        }}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="points-mall-admin-order-product">
                  <div class="points-mall-admin-order-product-thumb">
                    {{#if order.product_image_url}}
                      <img
                        src={{order.product_image_url}}
                        alt={{order.product_name}}
                      />
                    {{else if (eq order.display_product_type "physical")}}
                      {{dIcon "box"}}
                    {{else}}
                      {{dIcon "bolt"}}
                    {{/if}}
                  </div>
                  <div class="points-mall-admin-order-productinfo">
                    <strong>{{order.product_name}}</strong>
                    <p>
                      {{i18n
                        "points_mall.admin.orders.points_spent"
                        points=order.points_spent
                      }}
                    </p>
                  </div>
                </div>
              </div>

              <div class="points-mall-admin-order-edit">
                <div class="points-mall-admin-order-field">
                  <label>{{i18n
                      "points_mall.admin.orders.fields.status"
                    }}</label>
                  <select
                    class="points-mall-admin-select"
                    {{on "change" (fn @controller.setOrderStatus order)}}
                  >
                    {{#each @controller.model.orderStatuses as |status|}}
                      <option
                        selected={{eq order.status status}}
                        value={{status}}
                      >
                        {{i18n (concat "points_mall.orders.status." status)}}
                      </option>
                    {{/each}}
                  </select>
                </div>

                <div class="points-mall-admin-order-field --notes">
                  <label>{{i18n
                      "points_mall.admin.orders.fields.notes"
                    }}</label>
                  <Textarea
                    @value={{order.notes}}
                    class="points-mall-admin-order-notes-input"
                    {{on "input" (fn @controller.setOrderNotes order)}}
                    {{on "change" (fn @controller.setOrderNotes order)}}
                  />
                </div>

                <div class="points-mall-admin-order-field --shipping">
                  <label>{{i18n
                      "points_mall.admin.orders.fields.shipping_info"
                    }}</label>
                  <p>{{if
                      order.shipping_info
                      order.shipping_info
                      (i18n "points_mall.admin.orders.empty_shipping")
                    }}</p>
                </div>

                <div class="points-mall-admin-order-field --action">
                  <div class="points-mall-admin-order-actions">
                    <button
                      type="button"
                      class="btn btn-primary points-mall-admin-order-save-btn"
                      {{on "click" (fn @controller.saveOrder order)}}
                    >
                      {{i18n "points_mall.admin.actions.save"}}
                    </button>
                    <button
                      type="button"
                      class="btn btn-default points-mall-admin-order-cancel-btn"
                      {{on "click" (fn @controller.cancelOrderEdit order)}}
                    >
                      {{i18n "points_mall.admin.actions.cancel"}}
                    </button>
                  </div>
                </div>
              </div>
            </article>
          {{/each}}
        </div>
      {{else}}
        <div class="points-mall-admin-empty">
          {{i18n "points_mall.admin.orders.empty"}}
        </div>
      {{/if}}
    </section>
  </div>
</template>
