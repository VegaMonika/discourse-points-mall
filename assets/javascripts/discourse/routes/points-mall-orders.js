import DiscourseRoute from "discourse/routes/discourse";

export default class PointsMallOrdersRoute extends DiscourseRoute {
  async model() {
    try {
      const response = await fetch("/points-mall/orders.json");
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error loading orders:", error);
      return { orders: [] };
    }
  }
}
