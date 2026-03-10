import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
  @tracked orderTypeFilter = "all";
  @tracked pointsFilter = "all";

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

  get rankingUsers() {
    return this.checkinSummary.ranking || [];
  }

  get hasRankingUsers() {
    return this.rankingUsers.length > 0;
  }

  get makeupCardStatus() {
    return {
      purchased_count: 0,
      used_count: 0,
      available_count: 0,
      can_purchase: true,
      can_use: false,
      next_price: 1000,
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
    if (this.orderTypeFilter === "all") {
      return orders;
    }

    return orders.filter((order) => this.orderProductType(order) === this.orderTypeFilter);
  }

  get hasFilteredOrders() {
    return this.filteredOrders.length > 0;
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
  async checkin() {
    try {
      const result = await ajax("/points-mall/checkins", { type: "POST" });
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
  }

  @action
  setPointsFilter(filter) {
    this.pointsFilter = filter;
  }

  @action
  async makeUpCheckin(day) {
    if (!day?.date || !day?.can_makeup) {
      return;
    }

    try {
      const result = await ajax("/points-mall/checkins/makeup", {
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
  stopEvent(event) {
    event.stopPropagation();
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

      const result = await ajax("/points-mall/orders", {
        type: "POST",
        data,
      });
      const createdOrder = result.order || result;
      const isMakeupCard = Boolean(this.checkoutProduct?.is_makeup_card);

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

      this.activeTab = isMakeupCard ? "checkin" : "orders";
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
        await ajax(`/points-mall/addresses/${this.editingAddressId}`, {
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
      await ajax(`/points-mall/addresses/${addressId}`, {
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
      await ajax(`/points-mall/addresses/${addressId}`, {
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
    const result = await ajax("/points-mall/addresses");
    this.model.addresses = result.addresses || [];
    this.notifyPropertyChange("model");
    return this.model.addresses;
  }

  async reloadCheckinSummary() {
    const result = await ajax("/points-mall/checkins/summary");
    this.model.checkins = result.checkins || [];
    this.model.summary = result.summary || {};
    this.notifyPropertyChange("model");
  }

  async reloadProducts() {
    const result = await ajax("/points-mall/products");
    this.model.products = result.products || [];
    this.notifyPropertyChange("model");
  }

  async reloadLedger() {
    const result = await ajax("/points-mall/points/ledger");
    this.model.ledgerSummary = result.summary || {};
    this.model.ledgerEvents = result.events || [];
    this.notifyPropertyChange("model");
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

    const result = await ajax("/points-mall/addresses", {
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

  avatarUrl(template, size = 56) {
    return template ? template.replace("{size}", String(size)) : null;
  }
}
