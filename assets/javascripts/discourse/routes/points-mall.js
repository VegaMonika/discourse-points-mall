import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class PointsMallRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser) {
      this.transitionTo("login");
    }
  }

  async model() {
    const [checkins, products, orders, addresses, ledger] = await Promise.all([
      ajax("/points-mall/checkins/summary").catch(() => ({
        checkins: [],
        summary: {},
      })),
      ajax("/points-mall/products").catch(() => ({ products: [] })),
      ajax("/points-mall/orders").catch(() => ({ orders: [] })),
      ajax("/points-mall/addresses").catch(() => ({ addresses: [] })),
      ajax("/points-mall/points/ledger").catch(() => ({ summary: {}, events: [] })),
    ]);

    return {
      checkins: checkins.checkins || [],
      summary: checkins.summary || {},
      products: products.products || [],
      orders: orders.orders || [],
      addresses: addresses.addresses || [],
      ledgerSummary: ledger.summary || {},
      ledgerEvents: ledger.events || [],
    };
  }
}
