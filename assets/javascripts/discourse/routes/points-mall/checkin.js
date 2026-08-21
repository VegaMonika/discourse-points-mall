import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class PointsMallCheckinRoute extends DiscourseRoute {
  async model() {
    try {
      const response = await ajax("/loja/checkin/resumo");
      return response;
    } catch (error) {
      console.error("Error loading checkin data:", error);
      return { checkins: [], summary: {} };
    }
  }
}
