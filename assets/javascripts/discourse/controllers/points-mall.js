import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const MAX_ADDRESSES = 3;
const CALENDAR_WEEKDAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function blankAddressForm(isDefault = false) {
  return {
    recipient_name: "",
    phone: "",
    address_line: "",
    is_default: isDefault,
  };
}

export default class PointsMallController extends Controller {
  @service currentUser;
  @service appEvents;

  @tracked activeTab = "checkin";

  @tracked purchaseModalOpen = false;
  @tracked checkoutStep = null;
  @tracked checkoutProduct = null;
  @tracked checkoutSelectedAddressId = null;
  @tracked checkoutAddressForm = blankAddressForm(true);
  @tracked isSubmittingCheckout = false;

  @tracked showAddressEditor = false;
  @tracked editingAddressId = null;
  @tracked addressEditorForm = blankAddressForm(false);
  @tracked isSavingAddress = false;
  @tracked shopTypeFilter = "all";
  @tracked shopCategoryFilter = "all";
  @tracked shopKeyword = "";
  @tracked shopSort = "featured";
  @tracked orderTypeFilter = "all";
  @tracked ordersPage = 1;
  @tracked ordersPerPage = 5;
  @tracked pointsFilter = "all";
  @tracked ledgerPage = 1;
  @tracked ledgerPerPage = 15;
  @tracked copiedOrderId = null;

  updateCurrentUserPoints(delta) {
    const current = Number(this.currentUser?.points_balance || 0);
    const next = current + Number(delta || 0);
    if (typeof this.currentUser?.set === "function") {
      this.currentUser.set("points_balance", next);
    } else if (this.currentUser) {
      this.currentUser.points_balance = next;
    }
  }

  get tabs() {
    return [
      { name: "checkin", icon: "calendar-check" },
      { name: "shop", icon: "gift" },
      { name: "orders", icon: "list" },
      { name: "ledger", icon: "wallet" },
    ];
  }

  get checkinSummary() {
    return {
      current_streak: 0,
      current_month_checkins: 0,
      my_rank: null,
      my_score: 0,
      month_progress_percent: 0,
      ...(this.model.summary || {}),
    };
  }

  get levelProgress() {
    return {
      current_level: 0,
      current_name: "",
      current_points: Number(this.currentUser?.points_balance || 0),
      next_name: null,
      requirements_met: 0,
      requirements_total: 0,
      requirement_text: "",
      progress_percent: 0,
      ...(this.checkinSummary.level_progress || {}),
    };
  }

  get levelProgressStyle() {
    return htmlSafe(`width: ${Number(this.levelProgress.progress_percent || 0)}%`);
  }

  get rankingUsers() {
    return (this.checkinSummary.ranking || []).map((row) => ({
      ...row,
      avatar_url: this.avatarUrlFromTemplate(row.avatar_template, 56),
    }));
  }

  get hasRankingUsers() {
    return this.rankingUsers.length > 0;
  }

  get makeupCardStatus() {
    const defaults = this.makeupPricingDefaults;

    return {
      purchased_count: 0,
      used_count: 0,
      available_count: 0,
      can_purchase: true,
      can_use: false,
      next_price: defaults.tier_1,
      prices: defaults.prices,
      tier_1: defaults.tier_1,
      tier_2: defaults.tier_2,
      tier_3: defaults.tier_3,
      ...(this.checkinSummary.makeup_card || {}),
    };
  }

  get makeupProduct() {
    return (this.model.products || []).find((product) => product.is_makeup_card);
  }

  get canBuyMakeupCard() {
    return Boolean(this.makeupProduct?.purchaseable);
  }

  get makeupBuyButtonLabel() {
    const product = this.makeupProduct;
    if (!product) {
      return "points_mall.checkin.makeup_product_missing";
    }

    if (product.purchaseable) {
      return "points_mall.checkin.buy_makeup_card";
    }

    if (product.purchase_disabled_reason === "disabled") {
      return "points_mall.shop.makeup.off_shelf";
    }

    return "points_mall.shop.makeup.limit_reached";
  }

  get monthCalendarCells() {
    const days = this.checkinSummary.month_calendar || [];
    if (!days.length) {
      return [];
    }

    const firstDate = new Date(`${days[0].date}T00:00:00`);
    const weekday = (firstDate.getDay() + 6) % 7;
    const placeholders = Array.from({ length: weekday }).map((_, index) => ({
      id: `placeholder-${index}`,
      placeholder: true,
    }));

    return [...placeholders, ...days];
  }

  get calendarWeekdayKeys() {
    return CALENDAR_WEEKDAY_KEYS;
  }

  get pointsFilters() {
    return ["all", "income", "expense", "checkin", "shop", "community", "other"];
  }

  get shopProducts() {
    return (this.model.products || []).map((product) => this.decorateShopProduct(product));
  }

  get shopTypeFilters() {
    return ["all", "physical", "virtual"];
  }

  get shopSortOptions() {
    return ["featured", "popular", "price_asc", "price_desc", "latest"];
  }

  get shopCategoryOptions() {
    const keys = [];
    const seen = new Set();
    const products =
      this.shopTypeFilter === "all"
        ? this.shopProducts
        : this.shopProducts.filter((product) => product.product_type === this.shopTypeFilter);

    products.forEach((product) => {
      const key = this.shopCategoryKey(product);
      if (!seen.has(key)) {
        seen.add(key);
        keys.push(key);
      }
    });

    return [
      { key: "all", label: I18n.t("points_mall.shop.filters.category.all") },
      ...keys.map((key) => ({
        key,
        label: this.shopCategoryLabelByKey(key),
      })),
    ];
  }

  get filteredShopProducts() {
    const keyword = this.shopKeyword?.trim()?.toLowerCase() || "";

    const products = this.shopProducts.filter((product) => {
      if (this.shopTypeFilter !== "all" && product.product_type !== this.shopTypeFilter) {
        return false;
      }

      const categoryKey = this.shopCategoryKey(product);
      if (this.shopCategoryFilter !== "all" && categoryKey !== this.shopCategoryFilter) {
        return false;
      }

      if (!keyword) {
        return true;
      }

      const haystack = [product.name, product.description, product.category]
        .map((item) => (item || "").toLowerCase())
        .join(" ");
      return haystack.includes(keyword);
    });

    return [...products].sort((left, right) => this.compareShopProducts(left, right));
  }

  get shopSections() {
    const sectionMap = new Map();

    this.filteredShopProducts.forEach((product) => {
      const key = this.shopCategoryKey(product);
      if (!sectionMap.has(key)) {
        sectionMap.set(key, []);
      }
      sectionMap.get(key).push(product);
    });

    return Array.from(sectionMap.entries()).map(([key, products]) => ({
      key,
      label: this.shopCategoryLabelByKey(key),
      count: products.length,
      products,
    }));
  }

  get featuredShopProducts() {
    return this.filteredShopProducts.filter((product) => product.featured).slice(0, 4);
  }

  get showFeaturedShelf() {
    return (
      this.shopCategoryFilter === "all" &&
      !this.shopKeyword?.trim() &&
      this.featuredShopProducts.length > 0
    );
  }

  get shopInsights() {
    const products = this.filteredShopProducts;
    const categories = new Set(products.map((product) => this.shopCategoryKey(product)));
    const featured = products.filter((product) => product.featured).length;
    const redeemed = products.reduce(
      (sum, product) => sum + Number(product.redeemed_count || 0),
      0
    );

    return {
      productCount: products.length,
      categoryCount: categories.size,
      featuredCount: featured,
      redeemedCount: redeemed,
    };
  }

  get makeupPricingDefaults() {
    return {
      prices: [1000, 3000, 5000],
      tier_1: 1000,
      tier_2: 3000,
      tier_3: 5000,
    };
  }

  decorateShopProduct(product) {
    if (!product?.is_makeup_card) {
      return product;
    }

    const makeupCard = {
      ...this.makeupPricingDefaults,
      ...(product.makeup_card || {}),
    };

    return {
      ...product,
      makeup_card: makeupCard,
      makeup_tier_text: I18n.t("points_mall.shop.makeup.tiered_price", {
        first: makeupCard.tier_1,
        second: makeupCard.tier_2,
        third: makeupCard.tier_3,
      }),
    };
  }

  get pointsSummary() {
    return {
      income_count: 0,
      expense_count: 0,
      ...(this.model.ledgerSummary || {}),
    };
  }

  get filteredLedgerEvents() {
    const events = this.model.ledgerEvents || [];

    if (this.pointsFilter === "all") {
      return events;
    }

    if (this.pointsFilter === "income" || this.pointsFilter === "expense") {
      return events.filter((event) => event.direction === this.pointsFilter);
    }

    return events.filter((event) => event.category === this.pointsFilter);
  }

  get hasLedgerEvents() {
    return this.filteredLedgerEvents.length > 0;
  }

  get totalLedgerPages() {
    return Math.ceil(this.filteredLedgerEvents.length / this.ledgerPerPage) || 1;
  }

  get paginatedLedgerEvents() {
    const start = (this.ledgerPage - 1) * this.ledgerPerPage;
    return this.filteredLedgerEvents.slice(start, start + this.ledgerPerPage);
  }

  get orderTypeFilters() {
    return ["all", "physical", "virtual"];
  }

  get orderSummary() {
    const orders = this.model.orders || [];
    const physical = orders.filter((order) => this.orderProductType(order) === "physical").length;
    const virtual = orders.filter((order) => this.orderProductType(order) === "virtual").length;

    return {
      all: orders.length,
      physical,
      virtual,
    };
  }

  get filteredOrders() {
    const orders = this.model.orders || [];
    const filtered =
      this.orderTypeFilter === "all"
        ? orders
        : orders.filter((order) => this.orderProductType(order) === this.orderTypeFilter);

    return filtered.map((order) => ({
      ...order,
      display_product_type: this.orderProductType(order),
    }));
  }

  get hasFilteredOrders() {
    return this.filteredOrders.length > 0;
  }

  get paginatedOrders() {
    const start = (this.ordersPage - 1) * this.ordersPerPage;
    return this.filteredOrders.slice(start, start + this.ordersPerPage);
  }

  get ordersTotalPages() {
    return Math.ceil(this.filteredOrders.length / this.ordersPerPage) || 1;
  }

  get hasMultipleOrderPages() {
    return this.ordersTotalPages > 1;
  }

  get canPrevOrdersPage() {
    return this.ordersPage > 1;
  }

  get canNextOrdersPage() {
    return this.ordersPage < this.ordersTotalPages;
  }

  @action
  prevOrdersPage() {
    if (this.canPrevOrdersPage) {
      this.ordersPage--;
    }
  }

  @action
  nextOrdersPage() {
    if (this.canNextOrdersPage) {
      this.ordersPage++;
    }
  }

  get inventoryItems() {
    return this.model.inventory?.items || [];
  }

  get equippedInventory() {
    return this.model.inventory?.equipped || {};
  }

  get themeSkinTicketCount() {
    return Number(this.model.inventory?.theme_skin_ticket_count || 0);
  }

  get hasInventoryItems() {
    return this.inventoryItems.length > 0;
  }

  get activeInventoryItems() {
    return this.inventoryItems.filter((item) => !item.expired);
  }

  get expiredInventoryItems() {
    return this.inventoryItems.filter((item) => item.expired);
  }

  get equippedInventoryItems() {
    return Object.values(this.equippedInventory);
  }

  get hasEquippedInventory() {
    return this.equippedInventoryItems.length > 0;
  }

  get addresses() {
    return this.model.addresses || [];
  }

  get canCreateMoreAddresses() {
    return this.addresses.length < MAX_ADDRESSES;
  }

  get isEditingAddress() {
    return Boolean(this.editingAddressId);
  }

  get selectedCheckoutAddress() {
    return this.addresses.find((address) => address.id === this.checkoutSelectedAddressId);
  }

  get checkoutTitleKey() {
    if (this.checkoutStep === "virtual") {
      return "points_mall.checkout.virtual_title";
    }

    return "points_mall.checkout.physical_title";
  }

  get checkoutSubmitKey() {
    if (this.checkoutStep === "physical-form") {
      return "points_mall.checkout.submit_exchange";
    }

    return "points_mall.checkout.confirm_exchange";
  }

  @action
  switchTab(tab) {
    this.activeTab = tab;
  }

  @action
  setShopTypeFilter(filter) {
    this.shopTypeFilter = filter;
    this.shopCategoryFilter = "all";
  }

  @action
  setShopCategoryFilter(filter) {
    this.shopCategoryFilter = filter;
  }

  @action
  setShopSort(sort) {
    this.shopSort = sort;
  }

  @action
  updateShopKeyword(event) {
    this.shopKeyword = event?.target?.value || "";
  }

  @action
  async checkin() {
    try {
      const result = await ajax("/loja/checkin", { type: "POST" });
      const checkin = result.checkin || result;
      this.updateCurrentUserPoints(checkin.points_earned || 0);
      await this.reloadCheckinSummary();
      await this.reloadLedger();

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.checkin.success", {
          points: checkin.points_earned,
        }),
        messageClass: "success",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  setOrderTypeFilter(filter) {
    this.orderTypeFilter = filter;
    this.ordersPage = 1;
  }

  @action
  setPointsFilter(filter) {
    this.pointsFilter = filter;
    this.ledgerPage = 1;
  }

  @action
  prevLedgerPage() {
    if (this.ledgerPage > 1) {
      this.ledgerPage--;
    }
  }

  @action
  nextLedgerPage() {
    if (this.ledgerPage < this.totalLedgerPages) {
      this.ledgerPage++;
    }
  }

  @action
  async makeUpCheckin(day) {
    if (!day?.date || !day?.can_makeup) {
      return;
    }

    try {
      const result = await ajax("/loja/checkin/recuperar", {
        type: "POST",
        data: { checkin_date: day.date },
      });

      if (result.summary) {
        this.model.summary = result.summary;
      }
      if (result.makeup_card) {
        this.model.summary = {
          ...(this.model.summary || {}),
          makeup_card: result.makeup_card,
        };
      }

      await this.reloadCheckinSummary();
      await this.reloadProducts();
      await this.reloadLedger();

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.checkin.makeup_success"),
        messageClass: "success",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  goToShop() {
    this.activeTab = "shop";
  }

  @action
  buyMakeupCard() {
    if (!this.makeupProduct) {
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.checkin.makeup_product_missing"),
        messageClass: "warning",
      });
      return;
    }

    this.buyProduct(this.makeupProduct.id);
  }

  @action
  buyProduct(productId) {
    const product = this.model.products.find((item) => item.id === productId);
    if (!product) {
      return;
    }

    if (product.is_makeup_card && product.purchaseable === false) {
      const messageKey =
        product.purchase_disabled_reason === "disabled"
          ? "points_mall.shop.makeup.off_shelf"
          : "points_mall.shop.makeup.limit_reached";
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t(messageKey),
        messageClass: "warning",
      });
      return;
    }

    if (product.product_type === "physical") {
      this.openPhysicalCheckout(product);
      return;
    }

    this.checkoutProduct = product;
    this.checkoutStep = "virtual";
    this.purchaseModalOpen = true;
  }

  @action
  closePurchaseModal() {
    if (this.isSubmittingCheckout) {
      return;
    }

    this.resetPurchaseModal();
  }

  @action
  setCheckoutAddress(addressId) {
    this.checkoutSelectedAddressId = addressId;
  }

  @action
  useNewAddressInCheckout() {
    if (!this.canCreateMoreAddresses) {
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.max_reached", { count: MAX_ADDRESSES }),
        messageClass: "warning",
      });
      return;
    }

    this.checkoutAddressForm = blankAddressForm(false);
    this.checkoutStep = "physical-form";
  }

  @action
  backToAddressSelect() {
    if (!this.addresses.length) {
      return;
    }

    this.checkoutStep = this.addresses.length === 1 ? "physical-confirm" : "physical-select";
  }

  @action
  updateCheckoutAddressField(field, event) {
    this.checkoutAddressForm = {
      ...this.checkoutAddressForm,
      [field]: event.target.value,
    };
  }

  @action
  toggleCheckoutAddressDefault(event) {
    this.checkoutAddressForm = {
      ...this.checkoutAddressForm,
      is_default: event.target.checked,
    };
  }

  @action
  async submitCheckout() {
    if (!this.checkoutProduct || this.isSubmittingCheckout) {
      return;
    }

    this.isSubmittingCheckout = true;

    try {
      const data = { product_id: this.checkoutProduct.id };

      if (this.checkoutProduct.product_type === "physical") {
        if (this.checkoutStep === "physical-form") {
          const payload = this.normalizeAddressPayload(this.checkoutAddressForm);
          const addressId = await this.createAddress(payload);
          if (!addressId) {
            return;
          }
          data.address_id = addressId;
        } else {
          if (!this.checkoutSelectedAddressId) {
            this.appEvents.trigger("modal-body:flash", {
              text: I18n.t("points_mall.checkout.select_address_required"),
              messageClass: "warning",
            });
            return;
          }
          data.address_id = this.checkoutSelectedAddressId;
        }
      }

      const result = await ajax("/loja/pedidos", {
        type: "POST",
        data,
      });
      const createdOrder = result.order || result;
      const isMakeupCard = Boolean(this.checkoutProduct?.is_makeup_card);
      const isCosmetic = this.isCosmeticProduct(this.checkoutProduct);

      this.model.orders.unshift(createdOrder);

      if (result.makeup_card) {
        this.model.summary = {
          ...(this.model.summary || {}),
          makeup_card: result.makeup_card,
        };
      }

      if (
        this.checkoutProduct.stock !== -1 &&
        typeof this.checkoutProduct.stock === "number" &&
        this.checkoutProduct.stock > 0
      ) {
        this.checkoutProduct.stock -= 1;
      }

      this.updateCurrentUserPoints(
        -(createdOrder.points_spent || this.checkoutProduct.points_cost || 0)
      );

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.shop.purchase_success"),
        messageClass: "success",
      });

      await this.reloadProducts();
      await this.reloadLedger();
      await this.reloadCheckinSummary();
      await this.reloadInventory();

      this.activeTab = isMakeupCard ? "checkin" : isCosmetic ? "inventory" : "orders";
      this.notifyPropertyChange("model");
      this.resetPurchaseModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSubmittingCheckout = false;
    }
  }

  @action
  openCreateAddressEditor() {
    if (!this.canCreateMoreAddresses) {
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.max_reached", { count: MAX_ADDRESSES }),
        messageClass: "warning",
      });
      return;
    }

    this.editingAddressId = null;
    this.addressEditorForm = blankAddressForm(this.addresses.length === 0);
    this.showAddressEditor = true;
  }

  @action
  editAddress(address) {
    this.editingAddressId = address.id;
    this.addressEditorForm = {
      recipient_name: address.recipient_name,
      phone: address.phone,
      address_line: address.address_line,
      is_default: Boolean(address.is_default),
    };
    this.showAddressEditor = true;
  }

  @action
  cancelAddressEditor() {
    this.showAddressEditor = false;
    this.editingAddressId = null;
    this.addressEditorForm = blankAddressForm(false);
  }

  @action
  updateAddressEditorField(field, event) {
    this.addressEditorForm = {
      ...this.addressEditorForm,
      [field]: event.target.value,
    };
  }

  @action
  toggleAddressEditorDefault(event) {
    this.addressEditorForm = {
      ...this.addressEditorForm,
      is_default: event.target.checked,
    };
  }

  @action
  async saveAddressEditor() {
    if (this.isSavingAddress) {
      return;
    }

    this.isSavingAddress = true;

    try {
      const payload = this.normalizeAddressPayload(this.addressEditorForm);

      if (this.editingAddressId) {
        await ajax(`/loja/enderecos/${this.editingAddressId}`, {
          type: "PUT",
          data: payload,
        });
      } else {
        if (!this.canCreateMoreAddresses) {
          this.appEvents.trigger("modal-body:flash", {
            text: I18n.t("points_mall.addresses.max_reached", { count: MAX_ADDRESSES }),
            messageClass: "warning",
          });
          return;
        }

        const addressId = await this.createAddress(payload);
        if (!addressId) {
          return;
        }
      }

      await this.reloadAddresses();

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t(
          this.editingAddressId
            ? "points_mall.addresses.updated"
            : "points_mall.addresses.created"
        ),
        messageClass: "success",
      });

      this.cancelAddressEditor();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSavingAddress = false;
    }
  }

  @action
  async deleteAddress(addressId) {
    if (!window.confirm(I18n.t("points_mall.addresses.delete_confirm"))) {
      return;
    }

    try {
      await ajax(`/loja/enderecos/${addressId}`, {
        type: "DELETE",
      });
      await this.reloadAddresses();

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.deleted"),
        messageClass: "success",
      });

      if (this.editingAddressId === addressId) {
        this.cancelAddressEditor();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async setDefaultAddress(addressId) {
    try {
      await ajax(`/loja/enderecos/${addressId}`, {
        type: "PUT",
        data: { is_default: true },
      });
      await this.reloadAddresses();

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.default_updated"),
        messageClass: "success",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  openPhysicalCheckout(product) {
    this.checkoutProduct = product;
    this.checkoutAddressForm = blankAddressForm(this.addresses.length === 0);

    if (!this.addresses.length) {
      this.checkoutStep = "physical-form";
      this.checkoutSelectedAddressId = null;
    } else if (this.addresses.length === 1) {
      this.checkoutStep = "physical-confirm";
      this.checkoutSelectedAddressId = this.addresses[0].id;
    } else {
      const defaultAddress = this.addresses.find((address) => address.is_default);
      this.checkoutStep = "physical-select";
      this.checkoutSelectedAddressId = defaultAddress?.id || this.addresses[0].id;
    }

    this.purchaseModalOpen = true;
  }

  async reloadAddresses() {
    const result = await ajax("/loja/enderecos");
    this.model.addresses = result.addresses || [];
    this.notifyPropertyChange("model");
    return this.model.addresses;
  }

  async reloadCheckinSummary() {
    const result = await ajax("/loja/checkin/resumo");
    this.model.checkins = result.checkins || [];
    this.model.summary = result.summary || {};
    this.notifyPropertyChange("model");
  }

  async reloadProducts() {
    const result = await ajax("/loja/produtos");
    this.model.products = result.products || [];
    this.notifyPropertyChange("model");
  }

  async reloadLedger() {
    const result = await ajax("/loja/extrato");
    this.model.ledgerSummary = result.summary || {};
    this.model.ledgerEvents = result.events || [];
    this.notifyPropertyChange("model");
  }

  async reloadInventory() {
    const result = await ajax("/loja/inventario");
    this.model.inventory = result.inventory || { items: [], equipped: {} };
    this.notifyPropertyChange("model");
  }

  @action
  copyOrderDetails(order) {
    if (!order) return;
    const parts = [
      `Pedido #${order.id} - ${order.product?.name || 'Produto'}`,
      order.shipping_info ? `Endereço/Dados: ${order.shipping_info}` : null,
      order.notes ? `Observações/Entrega: ${order.notes}` : null,
    ].filter(Boolean);

    const textToCopy = parts.join("\n");
    if (!textToCopy) return;

    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(textToCopy).then(() => {
        this.copiedOrderId = order.id;
        setTimeout(() => {
          this.copiedOrderId = null;
        }, 3000);
      }).catch(() => {});
    }
  }

  @action
  async unequipInventoryKind(kind) {
    if (!kind) {
      return;
    }

    try {
      const result = await ajax("/loja/inventario/desequipar", {
        type: "POST",
        data: { kind },
      });
      this.model.inventory = result.inventory || { items: [], equipped: {} };
      this.broadcastCosmeticsUpdated(this.model.inventory);
      this.notifyPropertyChange("model");

      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.inventory.unequip_success"),
        messageClass: "success",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  normalizeAddressPayload(form) {
    return {
      recipient_name: form.recipient_name?.trim(),
      phone: form.phone?.trim(),
      address_line: form.address_line?.trim(),
      is_default: Boolean(form.is_default),
    };
  }

  validateAddressForm(form) {
    return Boolean(form.recipient_name && form.phone && form.address_line);
  }

  async createAddress(payload) {
    if (!this.validateAddressForm(payload)) {
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.required_error"),
        messageClass: "warning",
      });
      return null;
    }

    if (!this.canCreateMoreAddresses) {
      this.appEvents.trigger("modal-body:flash", {
        text: I18n.t("points_mall.addresses.max_reached", { count: MAX_ADDRESSES }),
        messageClass: "warning",
      });
      return null;
    }

    const result = await ajax("/loja/enderecos", {
      type: "POST",
      data: payload,
    });

    await this.reloadAddresses().catch(() => {});
    return result.address?.id;
  }

  resetPurchaseModal() {
    this.purchaseModalOpen = false;
    this.checkoutStep = null;
    this.checkoutProduct = null;
    this.checkoutSelectedAddressId = null;
    this.checkoutAddressForm = blankAddressForm(false);
  }

  orderProductType(order) {
    return order?.product?.product_type || "virtual";
  }

  isCosmeticProduct(product) {
    return String(product?.product_key || "").startsWith("cosmetic_");
  }

  broadcastCosmeticsUpdated(inventory) {
    window.dispatchEvent(
      new CustomEvent("jn:cosmetics-updated", {
        detail: { inventory },
      })
    );
  }

  avatarUrlFromTemplate(template, size = 56) {
    return template ? template.replace("{size}", String(size)) : null;
  }

  shopCategoryKey(product) {
    const key = (product?.category || "").trim();
    if (key.length) {
      return key;
    }

    return product?.product_type === "physical" ? "default_physical" : "default_virtual";
  }

  shopCategoryLabelByKey(key) {
    if (!key || key === "uncategorized") {
      return I18n.t("points_mall.shop.filters.category.uncategorized");
    }

    if (key === "default_physical") {
      return I18n.t("points_mall.shop.filters.category.default_physical");
    }

    if (key === "default_virtual") {
      return I18n.t("points_mall.shop.filters.category.default_virtual");
    }

    return key;
  }

  compareShopProducts(left, right) {
    switch (this.shopSort) {
      case "popular":
        return this.compareByPopular(left, right);
      case "price_asc":
        return this.compareByNumber(left?.points_cost, right?.points_cost, true);
      case "price_desc":
        return this.compareByNumber(left?.points_cost, right?.points_cost, false);
      case "latest":
        return this.compareByNumber(this.productCreatedAt(right), this.productCreatedAt(left), true);
      default:
        return this.compareByDefault(left, right);
    }
  }

  compareByDefault(left, right) {
    const featuredDiff = Number(Boolean(right?.featured)) - Number(Boolean(left?.featured));
    if (featuredDiff !== 0) {
      return featuredDiff;
    }

    const sortDiff = this.compareByNumber(left?.sort_order, right?.sort_order, true);
    if (sortDiff !== 0) {
      return sortDiff;
    }

    const popularDiff = this.compareByPopular(left, right);
    if (popularDiff !== 0) {
      return popularDiff;
    }

    return this.compareByNumber(this.productCreatedAt(right), this.productCreatedAt(left), true);
  }

  compareByPopular(left, right) {
    const redeemedDiff = this.compareByNumber(
      right?.redeemed_count,
      left?.redeemed_count,
      true
    );
    if (redeemedDiff !== 0) {
      return redeemedDiff;
    }

    return this.compareByNumber(this.productCreatedAt(right), this.productCreatedAt(left), true);
  }

  compareByNumber(left, right, asc = true) {
    const leftValue = Number(left || 0);
    const rightValue = Number(right || 0);

    if (leftValue === rightValue) {
      return 0;
    }

    return asc ? leftValue - rightValue : rightValue - leftValue;
  }

  productCreatedAt(product) {
    return Date.parse(product?.created_at || "") || 0;
  }
}
