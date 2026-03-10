# frozen_string_literal: true

module ::DiscoursePointsMall
  class PointsManager
    def self.enabled?
      defined?(::DiscourseGamification::GamificationScoreEvent) &&
        defined?(::DiscourseGamification::GamificationScore)
    end

    def self.balance_for(user)
      return 0 if user.blank?
      return 0 unless defined?(::DiscourseGamification::GamificationScore)

      ::DiscourseGamification::GamificationScore.where(user_id: user.id).sum(:score).to_i
    rescue StandardError
      0
    end

    def self.add_points!(user:, points:, description:)
      return false if user.blank?
      points = points.to_i
      return false if points.zero?
      return false unless enabled?

      today = Date.today
      ::DiscourseGamification::GamificationScoreEvent.create!(
        user_id: user.id,
        date: today,
        points: points,
        description: description,
      )
      ::DiscourseGamification::GamificationScore.calculate_scores(since_date: today)
      true
    rescue => e
      Rails.logger.warn("DiscoursePointsMall: 积分写入失败 - #{e.class}: #{e.message}")
      false
    end
  end
end
