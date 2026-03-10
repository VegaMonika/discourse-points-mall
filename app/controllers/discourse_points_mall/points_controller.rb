# frozen_string_literal: true

module DiscoursePointsMall
  class PointsController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    MAX_EVENTS = 200

    def ledger
      events = load_events

      render json: {
        summary: ledger_summary(events),
        events: events.map { |event| serialize_event(event) },
      }
    end

    private

    def load_events
      return [] unless defined?(::DiscourseGamification::GamificationScoreEvent)

      ::DiscourseGamification::GamificationScoreEvent
        .where(user_id: current_user.id)
        .order(date: :desc, created_at: :desc)
        .limit(MAX_EVENTS)
        .to_a
    rescue StandardError => e
      Rails.logger.warn("[points-mall] load ledger events failed: #{e.class} #{e.message}")
      []
    end

    def ledger_summary(events)
      category_counts = Hash.new(0)
      income_count = 0
      expense_count = 0

      events.each do |event|
        category_counts[event_category(event.description)] += 1
        points = event.points.to_i
        income_count += 1 if points.positive?
        expense_count += 1 if points.negative?
      end

      {
        current_points: current_user.points_balance.to_i,
        total_count: events.length,
        income_count: income_count,
        expense_count: expense_count,
        checkin_count: category_counts["checkin"],
        shop_count: category_counts["shop"],
        community_count: category_counts["community"],
        other_count: category_counts["other"],
      }
    end

    def serialize_event(event)
      points = event.points.to_i
      category = event_category(event.description)

      {
        id: event.id,
        date: event.date,
        created_at: event.created_at,
        points: points,
        description: event.description.presence || I18n.t("points_mall.points.unknown_description"),
        category: category,
        direction: points.negative? ? "expense" : "income",
      }
    end

    def event_category(description)
      text = description.to_s.downcase

      return "checkin" if text.include?("签到") || text.include?("check-in") || text.include?("checkin") || text.include?("每日")
      return "shop" if text.include?("商城") || text.include?("兑换商品") || text.include?("补签卡")
      return "community" if text.include?("社区") || text.include?("topic") || text.include?("reply") || text.include?("like") || text.include?("点赞")

      "other"
    end
  end
end
