import EmberObject from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

function defaultProduct() {
  return EmberObject.create({
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
}

function defaultMakeupConfig() {
  return {
    feature_ready: false,
    tier_1: 1000,
    tier_2: 3000,
    tier_3: 5000,
    prices: [1000, 3000, 5000],
  };
}

export default class AdminPluginsShowDiscoursePointsMallManage extends DiscourseRoute {
  async model() {
    const [productsRes, ordersRes, checkinsRes] =
      await Promise.all([
        ajax("/admin/plugins/discourse-points-mall/manage/products").catch(() => ({
          products: [],
        })),
        ajax("/admin/plugins/discourse-points-mall/manage/orders").catch(() => ({
          orders: [],
        })),
        ajax("/admin/plugins/discourse-points-mall/manage/checkins").catch(() => ({
          summary: {},
          trend: [],
          top_users: [],
          recent_checkins: [],
        })),
      ]);

    const products = new TrackedArray(
      (productsRes.products || []).map((item) => EmberObject.create(item))
    );
    const orders = new TrackedArray(
      (ordersRes.orders || []).map((item) =>
        EmberObject.create({
          ...item,
          notes: item.notes || "",
          _original_status: item.status || "pending",
          _original_notes: item.notes || "",
        })
      )
    );

    const checkinSummary = checkinsRes.summary || {};
    const checkinTrend = new TrackedArray(checkinsRes.trend || []);
    const checkinTopUsers = new TrackedArray(checkinsRes.top_users || []);
    const recentCheckins = new TrackedArray(checkinsRes.recent_checkins || []);

    return {
      products,
      orders,
      groups: productsRes.groups || [],
      checkinSummary,
      checkinTrend,
      checkinTopUsers,
      recentCheckins,
      dashboardStats: {
        products: products.length,
        totalOrders: orders.length,
        physicalOrders: orders.filter((order) => order.product_type === "physical").length,
        virtualOrders: orders.filter((order) => (order.product_type || "virtual") === "virtual")
          .length,
        pendingOrders: orders.filter((order) => order.status === "pending").length,
        todayCheckins: checkinSummary.today_checkins || 0,
        todayCheckinPoints: checkinSummary.today_points || 0,
      },
      newProduct: defaultProduct(),
      makeupConfig: EmberObject.create({
        ...defaultMakeupConfig(),
        ...(productsRes.makeup || {}),
      }),
      productTypes: ["virtual", "physical"],
      orderTypes: ["all", "physical", "virtual"],
      orderStatuses: ["pending", "processing", "completed", "cancelled"],
    };
  }
}
