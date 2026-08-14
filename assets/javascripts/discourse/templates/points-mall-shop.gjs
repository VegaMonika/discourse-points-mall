import { fn } from "@ember/helper";
import { eq, gt, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="points-mall-shop">
    <h2>{{i18n "points_mall.shop.title"}}</h2>

    <div class="products-grid">
      {{#each @controller.model.products as |product|}}
        <div class="product-card">
          {{#if product.image_url}}
            <div class="product-image">
              <img src={{product.image_url}} alt={{product.name}} />
            </div>
          {{/if}}
          <div class="product-info">
            <h3>{{product.name}}</h3>
            <p>{{product.description}}</p>
            <div class="product-meta">
              <span class="product-cost">
                {{i18n "points_mall.shop.cost" points=product.points_cost}}
              </span>
              <span class="product-stock">
                {{#if (eq product.stock -1)}}
                  {{i18n "points_mall.shop.unlimited"}}
                {{else if (gt product.stock 0)}}
                  {{i18n "points_mall.shop.stock" count=product.stock}}
                {{else}}
                  {{i18n "points_mall.shop.out_of_stock"}}
                {{/if}}
              </span>
            </div>
          </div>
          <div class="product-action">
            {{#if (or (eq product.stock -1) (gt product.stock 0))}}
              <DButton
                @action={{fn @controller.buyProduct product.id}}
                @label="points_mall.shop.buy"
                @icon="shopping-cart"
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
  </div>
</template>

