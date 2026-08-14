import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="points-mall-checkin">
    <div class="checkin-summary">
      <h2>{{i18n "points_mall.checkin.title"}}</h2>

      <div class="checkin-stats">
        <div class="stat-item">
          <span class="stat-label">{{i18n "points_mall.checkin.streak"}}</span>
          <span
            class="stat-value"
          >{{@controller.model.summary.current_streak}}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">{{i18n
              "points_mall.checkin.total_checkins"
            }}</span>
          <span
            class="stat-value"
          >{{@controller.model.summary.total_checkins}}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">{{i18n
              "points_mall.checkin.total_points"
            }}</span>
          <span
            class="stat-value"
          >{{@controller.model.summary.total_points}}</span>
        </div>
      </div>

      {{#if @controller.model.summary.checked_in_today}}
        <div class="already-checked-in">
          {{i18n "points_mall.checkin.already_checked"}}
        </div>
      {{else}}
        <DButton
          @action={{@controller.checkin}}
          @label="points_mall.checkin.button"
          @icon="calendar-check"
          class="btn-primary checkin-button"
        />
      {{/if}}
    </div>

    <div class="checkin-history">
      <h3>{{i18n "points_mall.checkin.history"}}</h3>
      <table class="checkin-table">
        <thead>
          <tr>
            <th>{{i18n "points_mall.checkin.date"}}</th>
            <th>{{i18n "points_mall.checkin.points"}}</th>
            <th>{{i18n "points_mall.checkin.streak"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.model.checkins as |checkin|}}
            <tr>
              <td>{{dFormatDate checkin.checkin_date}}</td>
              <td>{{checkin.points_earned}}</td>
              <td>{{checkin.streak_days}}</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </div>
</template>

