import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class PointsMallRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser) {
      this.transitionTo("login");
    }
  }

  async model() {
    const [checkins, products, orders, addresses, ledger, inventory] = await Promise.all([
      ajax("/loja/checkin/resumo").catch(() => ({
        checkins: [],
        summary: {},
      })),
      ajax("/loja/produtos").catch(() => ({ products: [] })),
      ajax("/loja/pedidos").catch(() => ({ orders: [] })),
      ajax("/loja/enderecos").catch(() => ({ addresses: [] })),
      ajax("/loja/extrato").catch(() => ({ summary: {}, events: [] })),
      ajax("/loja/inventario").catch(() => ({ inventory: { items: [], equipped: {} } })),
    ]);

    return {
      checkins: checkins.checkins || [],
      summary: checkins.summary || {},
      products: products.products || [],
      orders: orders.orders || [],
      addresses: addresses.addresses || [],
      ledgerSummary: ledger.summary || {},
      ledgerEvents: ledger.events || [],
      inventory: inventory.inventory || { items: [], equipped: {} },
    };
  }
}
