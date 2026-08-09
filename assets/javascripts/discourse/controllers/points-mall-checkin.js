import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class PointsMallCheckinController extends Controller {
  @service appEvents;

  @action
  async checkin() {
    try {
      const result = await ajax("/points-mall/checkins", {
        type: "POST",
      });

      this.model.checkins.unshift(result.checkin);
      this.model.summary.total_checkins += 1;
      this.model.summary.total_points += result.checkin.points_earned;
      this.model.summary.current_streak = result.checkin.streak_days;
      this.model.summary.checked_in_today = true;

      this.appEvents.trigger("modal-body:flash", {
        text: i18n("points_mall.checkin.success", {
          points: result.checkin.points_earned,
        }),
        messageClass: "success",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
