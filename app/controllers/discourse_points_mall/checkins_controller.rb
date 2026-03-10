# frozen_string_literal: true

module DiscoursePointsMall
  class CheckinsController < ::ApplicationController
    RANKING_LIMIT = 10
    PREFERRED_LEADERBOARD_ID = 2

    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    def index
      checkins = recent_checkins(current_user.id)
      render json: { checkins: serialize_checkins(checkins) }
    end

    def create
      return create_from_daily_checkin if using_daily_checkin?

      checkin = ::PointsMallCheckin.checkin_for_user(current_user)
      if checkin
        render json: serialize_data(checkin, DiscoursePointsMall::CheckinSerializer)
      else
        render_json_error(I18n.t('points_mall.errors.already_checked_in'), status: 422)
      end
    end

    def summary
      checkins = recent_checkins(current_user.id)

      render json: {
        checkins: serialize_checkins(checkins),
        summary: summary_payload,
      }
    end

    def makeup
      target_date = parse_target_date
      return render_json_error(I18n.t("points_mall.errors.invalid_makeup_date"), status: 422) if target_date.nil?

      result = perform_makeup(target_date)
      if result[:error]
        render_json_error(result[:error], status: 422)
      else
        render json: {
          checkin: result[:checkin],
          makeup_card: result[:makeup_card],
          summary: summary_payload,
        }
      end
    end

    private

    def using_daily_checkin?
      defined?(::DiscourseDailyCheckin::DailyCheckin)
    end

    def recent_checkins(user_id)
      if using_daily_checkin?
        ::DiscourseDailyCheckin::DailyCheckin.where(user_id: user_id).order(checked_in_on: :desc).limit(30)
      else
        ::PointsMallCheckin.for_user(user_id).recent.limit(30)
      end
    end

    def serialize_checkins(checkins)
      return serialize_data(checkins, DiscoursePointsMall::CheckinSerializer) unless using_daily_checkin?

      streaks = {}
      streak = 0
      previous_date = nil
      checkins.sort_by(&:checked_in_on).each do |checkin|
        if previous_date && checkin.checked_in_on == previous_date + 1
          streak += 1
        else
          streak = 1
        end
        streaks[checkin.id] = streak
        previous_date = checkin.checked_in_on
      end

      checkins.map do |checkin|
        {
          id: checkin.id,
          user_id: checkin.user_id,
          checkin_date: checkin.checked_in_on,
          points_earned: checkin.points_awarded,
          streak_days: streaks[checkin.id] || 1,
          created_at: checkin.created_at,
        }
      end
    end

    def all_checkin_dates(user_id)
      if using_daily_checkin?
        ::DiscourseDailyCheckin::DailyCheckin.where(user_id: user_id).pluck(:checked_in_on)
      else
        ::PointsMallCheckin.for_user(user_id).pluck(:checkin_date)
      end
    end

    def checkin_exists_on?(user_id, date)
      if using_daily_checkin?
        ::DiscourseDailyCheckin::DailyCheckin.exists?(user_id: user_id, checked_in_on: date)
      else
        ::PointsMallCheckin.exists?(user_id: user_id, checkin_date: date)
      end
    end

    def calculate_streak_for(date, checkin_dates)
      date_map = {}
      checkin_dates.each { |item| date_map[item] = true }
      streak = 0
      cursor = date

      while date_map[cursor]
        streak += 1
        cursor -= 1
      end

      streak
    end

    def level_progress_payload(user = current_user)
      current_level = (user.trust_level || 0).to_i.clamp(TrustLevel.valid_range.begin, TrustLevel.valid_range.end)
      current_points = user.points_balance.to_i

      if current_level >= TrustLevel[4]
        return {
                 current_level: current_level,
                 current_name: trust_level_name(current_level),
                 current_points: current_points,
                 next_level: nil,
                 next_name: nil,
                 progress_percent: 100,
                 requirements_met: 0,
                 requirements_total: 0,
                 requirement_text: I18n.t("points_mall.checkin.max_level"),
                 requirements: [],
               }
      end

      if current_level == TrustLevel[3]
        return {
                 current_level: current_level,
                 current_name: trust_level_name(current_level),
                 current_points: current_points,
                 next_level: TrustLevel[4],
                 next_name: trust_level_name(TrustLevel[4]),
                 progress_percent: 100,
                 requirements_met: 1,
                 requirements_total: 1,
                 requirement_text: I18n.t("points_mall.checkin.tl4_manual_requirement"),
                 requirements: [bool_requirement("tl4_manual_grant", true)],
               }
      end

      requirements = trust_level_requirements_for(user, current_level)
      requirements_met = requirements.count { |item| item[:met] }
      requirements_total = requirements.length
      progress_percent =
        if requirements_total.positive?
          ((requirements_met.to_f / requirements_total) * 100).round.clamp(0, 100)
        else
          0
        end

      {
        current_level: current_level,
        current_name: trust_level_name(current_level),
        current_points: current_points,
        next_level: current_level + 1,
        next_name: trust_level_name(current_level + 1),
        progress_percent: progress_percent,
        requirements_met: requirements_met,
        requirements_total: requirements_total,
        requirement_text: I18n.t("points_mall.checkin.requirements_progress", met: requirements_met, total: requirements_total),
        requirements: requirements,
      }
    end

    def trust_level_requirements_for(user, current_level)
      case current_level
      when TrustLevel[0]
        tl1_requirements(user)
      when TrustLevel[1]
        tl2_requirements(user)
      when TrustLevel[2]
        tl3_requirements(user)
      else
        []
      end
    rescue StandardError => e
      Rails.logger.warn("[points-mall] trust level progress failed: #{e.class} #{e.message}")
      []
    end

    def tl1_requirements(user)
      stat = user.user_stat
      minutes_read = stat&.time_read.to_i / 60
      account_age_mins = ((Time.zone.now - (user.created_at || Time.zone.now)) / 60).to_i

      [
        gte_requirement("topics_entered", stat&.topics_entered, SiteSetting.tl1_requires_topics_entered),
        gte_requirement("posts_read_count", stat&.posts_read_count, SiteSetting.tl1_requires_read_posts),
        gte_requirement("time_read_mins", minutes_read, SiteSetting.tl1_requires_time_spent_mins),
        gte_requirement("account_age_mins", account_age_mins, SiteSetting.tl1_requires_time_spent_mins),
      ]
    end

    def tl2_requirements(user)
      stat = user.user_stat
      minutes_read = stat&.time_read.to_i / 60
      account_age_mins = ((Time.zone.now - (user.created_at || Time.zone.now)) / 60).to_i
      topic_reply_count = stat ? stat.calc_topic_reply_count! : 0

      [
        gte_requirement("topics_entered", stat&.topics_entered, SiteSetting.tl2_requires_topics_entered),
        gte_requirement("posts_read_count", stat&.posts_read_count, SiteSetting.tl2_requires_read_posts),
        gte_requirement("time_read_mins", minutes_read, SiteSetting.tl2_requires_time_spent_mins),
        gte_requirement("account_age_mins", account_age_mins, SiteSetting.tl2_requires_time_spent_mins),
        gte_requirement("days_visited", stat&.days_visited, SiteSetting.tl2_requires_days_visited),
        gte_requirement("likes_received", stat&.likes_received, SiteSetting.tl2_requires_likes_received),
        gte_requirement("likes_given", stat&.likes_given, SiteSetting.tl2_requires_likes_given),
        gte_requirement("topic_reply_count", topic_reply_count, SiteSetting.tl2_requires_topic_reply_count),
      ]
    end

    def tl3_requirements(user)
      requirements = TrustLevel3Requirements.new(user)
      penalties = requirements.penalty_counts.total.to_i

      [
        bool_requirement("trust_level_unlocked", !requirements.trust_level_locked),
        bool_requirement("not_suspended", !user.suspended?),
        bool_requirement("not_silenced", !user.silenced?),
        bool_requirement("no_recent_penalties", penalties.zero?),
        gte_requirement("days_visited", requirements.days_visited, requirements.min_days_visited),
        gte_requirement("topics_replied_to", requirements.num_topics_replied_to, requirements.min_topics_replied_to),
        gte_requirement("topics_viewed", requirements.topics_viewed, requirements.min_topics_viewed),
        gte_requirement("posts_read", requirements.posts_read, requirements.min_posts_read),
        lte_requirement("flagged_posts", requirements.num_flagged_posts, requirements.max_flagged_posts),
        lte_requirement("flagged_by_users", requirements.num_flagged_by_users, requirements.max_flagged_by_users),
        gte_requirement("topics_viewed_all_time", requirements.topics_viewed_all_time, requirements.min_topics_viewed_all_time),
        gte_requirement("posts_read_all_time", requirements.posts_read_all_time, requirements.min_posts_read_all_time),
        gte_requirement("likes_given", requirements.num_likes_given, requirements.min_likes_given),
        gte_requirement("likes_received", requirements.num_likes_received, requirements.min_likes_received),
        gte_requirement("likes_received_users", requirements.num_likes_received_users, requirements.min_likes_received_users),
        gte_requirement("likes_received_days", requirements.num_likes_received_days, requirements.min_likes_received_days),
      ]
    end

    def gte_requirement(key, current, target)
      current_value = current.to_i
      target_value = target.to_i

      {
        key: key,
        current: current_value,
        target: target_value,
        comparator: ">=",
        met: current_value >= target_value,
      }
    end

    def lte_requirement(key, current, target)
      current_value = current.to_i
      target_value = target.to_i

      {
        key: key,
        current: current_value,
        target: target_value,
        comparator: "<=",
        met: current_value <= target_value,
      }
    end

    def bool_requirement(key, met)
      {
        key: key,
        current: met ? 1 : 0,
        target: 1,
        comparator: "==",
        met: met,
      }
    end

    def trust_level_name(level)
      TrustLevel.name(level)
    rescue StandardError
      I18n.t("points_mall.checkin.trust_level_fallback", level: level)
    end

    def ranking_payload(_current_points = nil)
      return { my_rank: nil, my_score: 0, total_users: 0, top_users: [] } unless defined?(::DiscourseGamification::GamificationLeaderboard)

      leaderboard = nil
      leaderboard = ::DiscourseGamification::GamificationLeaderboard.find_by(id: PREFERRED_LEADERBOARD_ID)
      if leaderboard.blank?
        Rails.logger.warn("[points-mall] leaderboard ##{PREFERRED_LEADERBOARD_ID} not found")
        return { my_rank: nil, my_score: 0, total_users: 0, top_users: [] }
      end
      if guardian.respond_to?(:can_see_leaderboard?) && !guardian.can_see_leaderboard?(leaderboard)
        return { my_rank: nil, my_score: 0, total_users: 0, top_users: [] }
      end

      period = leaderboard.resolve_period(nil)
      rows =
        ::DiscourseGamification::GamificationLeaderboard.scores_for(
          leaderboard.id,
          period: period,
          user_limit: RANKING_LIMIT,
        )

      my_row =
        ::DiscourseGamification::GamificationLeaderboard.find_position_by(
          leaderboard_id: leaderboard.id,
          for_user_id: current_user.id,
          period: period,
        )

      user_levels = ::User.where(id: rows.map(&:id)).pluck(:id, :trust_level).to_h
      top_users =
        rows.map do |row|
          points = row.total_score.to_i
          {
            rank: row.position.to_i,
            user_id: row.id.to_i,
            username: row.username,
            avatar_template: row.avatar_template,
            points: points,
            level_name: trust_level_name(user_levels[row.id].to_i),
          }
        end

      {
        my_rank: my_row&.position&.to_i,
        my_score: my_row&.total_score.to_i,
        total_users: [rows.length, my_row&.position.to_i].compact.max.to_i,
        top_users: top_users,
      }
    rescue ::DiscourseGamification::LeaderboardCachedView::NotReadyError
      Jobs.enqueue(Jobs::GenerateLeaderboardPositions, leaderboard_id: leaderboard.id) if leaderboard
      { my_rank: nil, my_score: 0, total_users: 0, top_users: [] }
    rescue StandardError => e
      Rails.logger.warn("[points-mall] ranking payload failed: #{e.class} #{e.message}")
      { my_rank: nil, my_score: 0, total_users: 0, top_users: [] }
    end

    def default_makeup_card_status
      month_key = Time.zone.today.beginning_of_month
      {
        month_key: month_key,
        max_per_month: 3,
        purchased_count: 0,
        used_count: 0,
        available_count: 0,
        can_purchase: true,
        can_use: false,
        next_price: 1000,
        prices: [1000, 3000, 5000],
        expires_at: month_key.end_of_month,
      }
    end

    def makeup_card_status(user = current_user)
      return default_makeup_card_status unless defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?

      ::PointsMallMakeupCard.fetch_or_create_for(user.id).status_payload
    rescue StandardError => e
      Rails.logger.warn("[points-mall] makeup card status failed: #{e.class} #{e.message}")
      default_makeup_card_status
    end

    def month_calendar_payload(checkin_dates:, today:, makeup_card:)
      month_start = today.beginning_of_month
      month_end = today.end_of_month
      date_map = {}
      checkin_dates.each { |item| date_map[item] = true }

      days_raw =
        (month_start..month_end).map do |date|
          status =
            if date > today
              "future"
            elsif date_map[date]
              "checked"
            elsif date == today
              "today"
            else
              "missed"
            end

          {
            date: date,
            day: date.day,
            status: status,
            can_makeup: status == "missed" && makeup_card[:can_use],
            is_today: date == today,
          }
        end

      passed_days = today.day
      checked_until_today = days_raw.count { |day| day[:status] == "checked" && day[:date] <= today }
      progress_percent = passed_days.positive? ? ((checked_until_today.to_f / passed_days) * 100).round : 0
      days = days_raw.map { |day| day.merge(date: day[:date].iso8601) }

      {
        days: days,
        progress_percent: progress_percent,
        checked_until_today: checked_until_today,
      }
    end

    def summary_payload
      today = Time.zone.today
      checkin_dates = all_checkin_dates(current_user.id)
      date_map = {}
      checkin_dates.each { |item| date_map[item] = true }

      month_start = today.beginning_of_month
      month_end = today.end_of_month
      current_month_checkins = checkin_dates.count { |date| date >= month_start && date <= month_end }
      checked_in_today = date_map[today]
      current_streak = calculate_streak_for(today, checkin_dates)

      total_points =
        if using_daily_checkin?
          ::DiscourseDailyCheckin::DailyCheckin.where(user_id: current_user.id).sum(:points_awarded)
        else
          ::PointsMallCheckin.for_user(current_user.id).sum(:points_earned)
        end

      current_points = current_user.points_balance.to_i
      level_progress = level_progress_payload
      ranking = ranking_payload(current_points)
      makeup_card = makeup_card_status
      calendar = month_calendar_payload(checkin_dates: checkin_dates, today: today, makeup_card: makeup_card)

      {
        total_checkins: checkin_dates.length,
        total_points: total_points,
        current_streak: current_streak,
        checked_in_today: checked_in_today,
        current_month_checkins: current_month_checkins,
        current_level: level_progress[:current_name],
        level_progress: level_progress,
        my_rank: ranking[:my_rank],
        my_score: ranking[:my_score],
        rank_total_users: ranking[:total_users],
        ranking: ranking[:top_users],
        month_progress_percent: calendar[:progress_percent],
        month_calendar: calendar[:days],
        makeup_card: makeup_card,
      }
    end

    def parse_target_date
      value = params[:checkin_date].presence || params[:date].presence
      return nil if value.blank?
      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def perform_makeup(target_date)
      unless defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?
        return { error: I18n.t("points_mall.errors.makeup_unavailable") }
      end

      return { error: I18n.t("points_mall.errors.makeup_current_month_only") } unless target_date.beginning_of_month == Time.zone.today.beginning_of_month
      return { error: I18n.t("points_mall.errors.makeup_past_days_only") } unless target_date < Time.zone.today

      error = nil
      checkin_payload = nil
      makeup_payload = nil

      ::PointsMallMakeupCard.transaction do
        locked_user = ::User.lock.find(current_user.id)
        month_key = ::PointsMallMakeupCard.month_key_for(Time.zone.today)
        card = fetch_locked_makeup_card(locked_user.id, month_key)

        if checkin_exists_on?(locked_user.id, target_date)
          error = I18n.t("points_mall.errors.date_already_checked_in")
          raise ActiveRecord::Rollback
        end

        unless card.can_use?
          error = I18n.t("points_mall.errors.no_makeup_card")
          raise ActiveRecord::Rollback
        end

        if using_daily_checkin?
          checkin =
            ::DiscourseDailyCheckin::DailyCheckin.create!(
              user_id: locked_user.id,
              checked_in_on: target_date,
              points_awarded: 0,
            )

          dates = all_checkin_dates(locked_user.id)
          streak = calculate_streak_for(target_date, dates)
          checkin_payload = {
            id: checkin.id,
            user_id: checkin.user_id,
            checkin_date: checkin.checked_in_on,
            points_earned: checkin.points_awarded,
            streak_days: streak,
            created_at: checkin.created_at,
          }
        else
          checkin =
            ::PointsMallCheckin.create!(
              user_id: locked_user.id,
              checkin_date: target_date,
              points_earned: 0,
              streak_days: 1,
            )
          checkin_payload = {
            id: checkin.id,
            user_id: checkin.user_id,
            checkin_date: checkin.checkin_date,
            points_earned: checkin.points_earned,
            streak_days: checkin.streak_days,
            created_at: checkin.created_at,
          }
        end

        card.use_one!
        makeup_payload = card.status_payload
      end

      return { error: error } if error

      {
        checkin: checkin_payload,
        makeup_card: makeup_payload || makeup_card_status,
      }
    rescue ActiveRecord::RecordNotUnique
      { error: I18n.t("points_mall.errors.date_already_checked_in") }
    rescue StandardError => e
      Rails.logger.warn("[points-mall] makeup failed: #{e.class} #{e.message}")
      { error: I18n.t("points_mall.errors.makeup_failed") }
    end

    def fetch_locked_makeup_card(user_id, month_key)
      card = ::PointsMallMakeupCard.lock.for_user_month(user_id, month_key).first
      return card if card

      ::PointsMallMakeupCard.create!(
        user_id: user_id,
        month_key: month_key,
        purchased_count: 0,
        used_count: 0,
      )
    rescue ActiveRecord::RecordNotUnique
      ::PointsMallMakeupCard.lock.for_user_month(user_id, month_key).first!
    end

    def create_from_daily_checkin
      if ::DiscourseDailyCheckin::DailyCheckin.checked_in_today?(current_user)
        return render_json_error(I18n.t('points_mall.errors.already_checked_in'), status: 422)
      end

      checkin =
        ::DiscourseDailyCheckin::DailyCheckin.create!(
          user_id: current_user.id,
          checked_in_on: Time.zone.today,
          points_awarded: 0,
        )

      streak = ::DiscourseDailyCheckin::DailyCheckin.current_streak_for(current_user)
      base_points = SiteSetting.respond_to?(:daily_checkin_points) ? SiteSetting.daily_checkin_points : SiteSetting.points_mall_checkin_points
      bonus_points = 0

      if SiteSetting.respond_to?(:daily_checkin_streak_reward_enabled) &&
           SiteSetting.daily_checkin_streak_reward_enabled
        reward_days = SiteSetting.daily_checkin_streak_reward_days.to_i
        if reward_days > 0 && streak > 0 && (streak % reward_days).zero?
          bonus_points = SiteSetting.daily_checkin_streak_reward_points.to_i
        end
      end

      total_points = base_points + bonus_points
      checkin.update_columns(points_awarded: total_points, updated_at: Time.zone.now)

      DiscoursePointsMall::PointsManager.add_points!(
        user: current_user,
        points: total_points,
        description: (SiteSetting.respond_to?(:daily_checkin_score_description) ? SiteSetting.daily_checkin_score_description : "每日签到"),
      )

      render json: {
        checkin: {
          id: checkin.id,
          user_id: checkin.user_id,
          checkin_date: checkin.checked_in_on,
          points_earned: checkin.points_awarded,
          streak_days: streak,
          created_at: checkin.created_at,
        },
      }
    rescue ActiveRecord::RecordNotUnique
      render_json_error(I18n.t('points_mall.errors.already_checked_in'), status: 422)
    end
  end
end
