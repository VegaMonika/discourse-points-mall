import EmberObject from "@ember/object";
import { action, set } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { service } from "@ember/service";
import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

function boolFromEvent(event) {
  return !!event?.target?.checked;
}

export default class AdminPluginsShowDiscoursePointsMallManageController extends Controller {
  @service toasts;
  @tracked adminActiveTab = "overview";
  @tracked showNewProductAccordion = false;
  @tracked showMakeupAccordion = false;
  @tracked adminProductQuery = "";
  @tracked adminOrderTypeFilter = "all";
  @tracked adminOrderStatusFilter = "all";
  @tracked adminOrderQuery = "";
  @tracked orderEditVersion = 0;
  @tracked editingProductId = null;

  @action
  setAdminActiveTab(tabName) {
    this.adminActiveTab = tabName;
  }

  @action
  toggleNewProductAccordion() {
    this.showNewProductAccordion = !this.showNewProductAccordion;
  }

  @action
  toggleMakeupAccordion() {
    this.showMakeupAccordion = !this.showMakeupAccordion;
  }

  @action
  updateAdminProductQuery(event) {
    this.adminProductQuery = event?.target?.value || "";
  }

  get filteredAdminProducts() {
    const products = this.model.products || [];
    const query = (this.adminProductQuery || "").trim().toLowerCase();
    if (!query) {
      return products;
    }
    return products.filter((p) => {
      const nameMatch = (p.name || "").toLowerCase().includes(query);
      const catMatch = (p.category || "").toLowerCase().includes(query);
      const descMatch = (p.description || "").toLowerCase().includes(query);
      return nameMatch || catMatch || descMatch;
    });
  }

  @action
  toggleEditProduct(product) {
    if (this.editingProductId === product.id) {
      this.editingProductId = null;
    } else {
      this.editingProductId = product.id;
    }
  }

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
      category: (product.category || "").trim(),
      featured: !!product.featured,
      badge_text: (product.badge_text || "").trim(),
      image_url: product.image_url,
      enabled: !!product.enabled,
      price_brl: product.price_brl !== "" && product.price_brl !== null && product.price_brl !== undefined ? Number(product.price_brl) : null,
      external_url: (product.external_url || "").trim(),
      grant_group_id: product.grant_group_id !== "" && product.grant_group_id !== null && product.grant_group_id !== undefined ? Number(product.grant_group_id) : null,
      grant_duration_days: product.grant_duration_days !== "" && product.grant_duration_days !== null && product.grant_duration_days !== undefined ? Number(product.grant_duration_days) : null,
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

    const query = (this.adminOrderQuery || "").trim().toLowerCase();
    if (query) {
      orders = orders.filter((order) => {
        const idMatch = String(order.id).includes(query);
        const userMatch = (order.username || "").toLowerCase().includes(query);
        const productMatch = (order.product_name || "").toLowerCase().includes(query);
        return idMatch || userMatch || productMatch;
      });
    }

    return orders.map((order) => {
      const displayProductType = this.adminOrderType(order);
      set(order, "display_product_type", displayProductType);
      set(order, "avatar_url", this.avatarUrlFromTemplate(order.avatar_template, 48));
      set(order, "user_role_label_key", this.userRoleLabelKey(order));
      set(order, "user_role_class", this.userRoleClass(order));
      return order;
    });
  }

  get adminOrderStatuses() {
    const list = this.model.orderStatuses || ["pending", "completed", "shipped", "canceled"];
    if (!list.includes("refunded")) {
      return ["all", ...list, "refunded"];
    }
    return ["all", ...list];
  }

  adminOrderType(order) {
    return order?.product_type || "virtual";
  }

  @action
  isOrderDirty(order) {
    // Force recomputation after local edit handlers run
    this.orderEditVersion;
    return (
      (order?.status || "") !== (order?._original_status || "") ||
      (order?.notes || "") !== (order?._original_notes || "")
    );
  }

  avatarUrlFromTemplate(template, size = 45) {
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
      data: { message: typeof I18n !== "undefined" ? I18n.t("saved") : i18n("saved") },
      duration: "short",
    });
  }

  updateMakeupConfigValue(field, event) {
    const nextValue = Number(event?.target?.value || 0);
    set(this.model.makeupConfig, field, nextValue);
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
        category: "",
        featured: false,
        badge_text: "",
        image_url: "",
        enabled: true,
        price_brl: "",
        external_url: "",
        grant_group_id: "",
        grant_duration_days: "",
        sort_order: 0,
      });
      this.showNewProductAccordion = false;
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
  setMakeupTier(field, event) {
    this.updateMakeupConfigValue(field, event);
  }

  @action
  async saveMakeupConfig() {
    try {
      const makeupConfig = this.model.makeupConfig;
      const res = await ajax("/admin/plugins/discourse-points-mall/manage/makeup-config", {
        type: "PUT",
        data: {
          tier_1: Number(makeupConfig.tier_1 || 0),
          tier_2: Number(makeupConfig.tier_2 || 0),
          tier_3: Number(makeupConfig.tier_3 || 0),
        },
      });

      Object.entries(res.makeup || {}).forEach(([key, value]) => set(makeupConfig, key, value));

      const makeupProduct = this.model.products.find((product) => product.is_makeup_card);
      if (makeupProduct) {
        set(makeupProduct, "points_cost", Number(res.makeup?.tier_1 || makeupProduct.points_cost || 0));
      }

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
  setProductGroup(product, event) {
    const val = event.target.value;
    set(product, "grant_group_id", val ? Number(val) : null);
  }

  @action
  setProductEnabled(product, event) {
    product.enabled = boolFromEvent(event);
  }

  @action
  setProductFeatured(product, event) {
    product.featured = boolFromEvent(event);
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
  updateAdminOrderQuery(event) {
    this.adminOrderQuery = event?.target?.value || "";
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
  async refundOrder(order) {
    if (!order?.id) return;
    const confirmText = `Tem certeza que deseja REEMBOLSAR o pedido #${order.id} (${order.product_name || 'Produto'})?\n\n- ${order.points_spent || 0} pontos serão devolvidos ao usuário (${order.username || 'Usuário'}).\n- Caso o produto conceda um grupo VIP, a permissão será revogada.`;

    if (!window.confirm(confirmText)) {
      return;
    }

    try {
      const res = await ajax(`/admin/plugins/discourse-points-mall/manage/orders/${order.id}/refund`, {
        type: "POST",
      });

      Object.entries(res.order || {}).forEach(([key, value]) => set(order, key, value));
      set(order, "_original_status", order.status || "refunded");
      set(order, "_original_notes", order.notes || "");
      this.orderEditVersion += 1;
      this.refreshDashboardStats();

      this.toasts.success({
        data: { message: "Pedido reembolsado com sucesso! Pontos estornados ao usuário." },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    }
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
