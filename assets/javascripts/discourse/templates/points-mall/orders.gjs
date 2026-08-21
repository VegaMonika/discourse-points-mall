import { concat } from "@ember/helper";
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

export default <template>
  <div class="points-mall-orders">
    <h2>{{i18n "points_mall.orders.title"}}</h2>

    {{#if @controller.model.orders}}
      <div class="orders-list">
        {{#each @controller.model.orders as |order|}}
          <div class="order-card">
            <div class="order-info">
              <h3>{{order.product.name}}</h3>
              <div class="order-meta">
                <span class="order-cost">
                  {{i18n "points_mall.shop.cost" points=order.points_spent}}
                </span>
                <span class="order-status status-{{order.status}}">
                  {{i18n (concat "points_mall.orders.status." order.status)}}
                </span>
                <span class="order-date">
                  {{formatDateFixed order.created_at}}
                </span>
              </div>
              {{#if order.shipping_info}}
                <div class="order-shipping">
                  <strong>{{i18n "points_mall.orders.shipping_info"}}:</strong>
                  <p>{{order.shipping_info}}</p>
                </div>
              {{/if}}
              {{#if order.notes}}
                <div class="order-notes">
                  <strong>{{i18n "points_mall.orders.notes"}}:</strong>
                  <p>{{order.notes}}</p>
                </div>
              {{/if}}
            </div>
          </div>
        {{/each}}
      </div>
    {{else}}
      <div class="empty-state">
        {{dIcon "inbox"}}
        <p>{{i18n "points_mall.orders.empty"}}</p>
      </div>
    {{/if}}
  </div>
</template>
