import EmberObject from "@ember/object";
import { action, set } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { service } from "@ember/service";
import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

function boolFromEvent(event) {
  return !!event?.target?.checked;
}

export default class AdminPluginsShowDiscoursePointsMallManageController extends Controller {
  @service toasts;
  @tracked adminOrderTypeFilter = "all";
  @tracked adminOrderStatusFilter = "all";
  @tracked orderEditVersion = 0;

  productPayload(product) {
    return {
      name: product.name,
      description: product.description,
      points_cost: Number(product.points_cost || 0),
      stock:
        product.stock === "" || product.stock === null || product.stock === undefined
          ? -1
          : Number(product.stock),
      product_type: product.product_type || "virtual",
      image_url: product.image_url,
      enabled: !!product.enabled,
      sort_order: Number(product.sort_order || 0),
    };
  }

  refreshDashboardStats() {
    this.model.dashboardStats = {
      products: this.model.products.length,
      totalOrders: this.model.orders.length,
      physicalOrders: this.model.orders.filter((order) => this.adminOrderType(order) === "physical")
        .length,
      virtualOrders: this.model.orders.filter((order) => this.adminOrderType(order) === "virtual")
        .length,
      pendingOrders: this.model.orders.filter((order) => order.status === "pending").length,
      todayCheckins: this.model.checkinSummary?.today_checkins || 0,
      todayCheckinPoints: this.model.checkinSummary?.today_points || 0,
    };
    this.notifyPropertyChange("model");
  }

  get filteredAdminOrders() {
    let orders = this.model.orders || [];

    if (this.adminOrderTypeFilter !== "all") {
      orders = orders.filter((order) => this.adminOrderType(order) === this.adminOrderTypeFilter);
    }

    if (this.adminOrderStatusFilter !== "all") {
      orders = orders.filter((order) => order.status === this.adminOrderStatusFilter);
    }

    return orders;
  }

  get adminOrderStatuses() {
    return ["all", ...(this.model.orderStatuses || [])];
  }

  adminOrderType(order) {
    return order?.product_type || "virtual";
  }

  isOrderDirty(order) {
    // Force recomputation after local edit handlers run, even when EmberObject
    // property tracking behaves inconsistently in template method calls.
    this.orderEditVersion;
    return (
      (order?.status || "") !== (order?._original_status || "") ||
      (order?.notes || "") !== (order?._original_notes || "")
    );
  }

  avatarUrl(template, size = 45) {
    return template ? template.replace("{size}", String(size)) : null;
  }

  userRoleLabelKey(order) {
    if (order.is_admin) {
      return "points_mall.admin.orders.roles.admin";
    }
    if (order.is_moderator) {
      return "points_mall.admin.orders.roles.moderator";
    }
    if (order.is_staff) {
      return "points_mall.admin.orders.roles.staff";
    }
    return "points_mall.admin.orders.roles.user";
  }

  userRoleClass(order) {
    if (order.is_admin) {
      return "role-admin";
    }
    if (order.is_moderator) {
      return "role-moderator";
    }
    if (order.is_staff) {
      return "role-staff";
    }
    return "role-user";
  }

  success() {
    this.toasts.success({
      data: { message: I18n.t("saved") },
      duration: "short",
    });
  }

  @action
  async createProduct() {
    try {
      const payload = this.productPayload(this.model.newProduct);
      const res = await ajax("/admin/plugins/discourse-points-mall/manage/products", {
        type: "POST",
        data: payload,
      });

      this.model.products.unshift(EmberObject.create(res.product));
      this.model.newProduct = EmberObject.create({
        name: "",
        description: "",
        points_cost: 100,
        stock: -1,
        product_type: "virtual",
        image_url: "",
        enabled: true,
        sort_order: 0,
      });
      this.refreshDashboardStats();
      this.success();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async saveProduct(product) {
    try {
      const payload = this.productPayload(product);
      const res = await ajax(
        `/admin/plugins/discourse-points-mall/manage/products/${product.id}`,
        {
          type: "PUT",
          data: payload,
        }
      );
      Object.assign(product, res.product);
      this.success();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deleteProduct(product) {
    try {
      await ajax(`/admin/plugins/discourse-points-mall/manage/products/${product.id}`, {
        type: "DELETE",
      });
      const index = this.model.products.indexOf(product);
      if (index > -1) {
        this.model.products.splice(index, 1);
      }
      this.refreshDashboardStats();
      this.success();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  setProductType(product, event) {
    product.product_type = event.target.value;
  }

  @action
  setProductEnabled(product, event) {
    product.enabled = boolFromEvent(event);
  }

  @action
  setOrderStatus(order, event) {
    set(order, "status", event?.target?.value || "pending");
    this.orderEditVersion += 1;
  }

  @action
  setOrderNotes(order, event) {
    set(order, "notes", event?.target?.value || "");
    this.orderEditVersion += 1;
  }

  @action
  setAdminOrderTypeFilter(type) {
    this.adminOrderTypeFilter = type;
  }

  @action
  setAdminOrderStatusFilter(statusOrEvent) {
    this.adminOrderStatusFilter = statusOrEvent?.target?.value || statusOrEvent;
  }

  @action
  async saveOrder(order) {
    try {
      const res = await ajax(`/admin/plugins/discourse-points-mall/manage/orders/${order.id}`, {
        type: "PUT",
        data: {
          status: order.status,
          notes: order.notes,
        },
      });
      Object.entries(res.order || {}).forEach(([key, value]) => set(order, key, value));
      set(order, "notes", order.notes || "");
      set(order, "_original_status", order.status || "pending");
      set(order, "_original_notes", order.notes || "");
      this.orderEditVersion += 1;
      this.refreshDashboardStats();
      this.success();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  cancelOrderEdit(order) {
    set(order, "status", order._original_status || "pending");
    set(order, "notes", order._original_notes || "");
    this.orderEditVersion += 1;
  }

  @action
  async reloadCheckinSummary() {
    try {
      const result = await ajax("/admin/plugins/discourse-points-mall/manage/checkins");
      this.model.checkinSummary = result.summary || {};
      this.model.checkinTrend = new TrackedArray(result.trend || []);
      this.model.checkinTopUsers = new TrackedArray(result.top_users || []);
      this.model.recentCheckins = new TrackedArray(result.recent_checkins || []);
      this.refreshDashboardStats();
      this.success();
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
