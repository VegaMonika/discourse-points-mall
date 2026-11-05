import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

function productList(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }
  return payload?.products || [];
}

export default class PointsMallRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser) {
      this.transitionTo("login");
    }
  }

  async model() {
    const [checkins, products, orders, addresses, ledger, inventory] = await Promise.all([
      ajax("/points-mall/checkins/summary").catch(() => ({
        checkins: [],
        summary: {},
      })),
      ajax("/points-mall/products.json"),
      ajax("/points-mall/orders").catch(() => ({ orders: [] })),
      ajax("/points-mall/addresses").catch(() => ({ addresses: [] })),
      ajax("/points-mall/points/ledger").catch(() => ({ summary: {}, events: [] })),
      ajax("/points-mall/inventory").catch(() => ({ inventory: { items: [], equipped: {} } })),
    ]);

    return {
      checkins: checkins.checkins || [],
      summary: checkins.summary || {},
      products: productList(products),
      orders: orders.orders || [],
      addresses: addresses.addresses || [],
      ledgerSummary: ledger.summary || {},
      ledgerEvents: ledger.events || [],
      inventory: inventory.inventory || { items: [], equipped: {} },
    };
  }
}