import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class PointsMallCheckinRoute extends DiscourseRoute {
  async model() {
    try {
      const response = await ajax("/points-mall/checkins/summary");
      return response;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error loading checkin data:", error);
      return { checkins: [], summary: {} };
    }
  }
}
