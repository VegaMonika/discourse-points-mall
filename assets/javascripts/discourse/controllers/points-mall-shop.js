import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PointsMallShopController extends Controller {
  @service currentUser;
  @service router;
  @service appEvents;

  @action
  async buyProduct(productId) {
    if (!confirm(I18n.t("points_mall.shop.confirm_purchase"))) {
      return;
    }

    try {
      await ajax("/points-mall/orders", {
        type: "POST",
        data: { product_id: productId },
      });

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.shop.purchase_success"),
        messageClass: "success",
      });

      this.router.transitionTo("points-mall.orders");
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
