import DiscourseRoute from "discourse/routes/discourse";

export default class PointsMallShopRoute extends DiscourseRoute {
  async model() {
    try {
      const response = await fetch("/points-mall/products.json");
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error loading products:", error);
      return { products: [] };
    }
  }
}
