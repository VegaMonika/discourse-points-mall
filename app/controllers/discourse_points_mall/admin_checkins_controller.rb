# frozen_string_literal: true

module DiscoursePointsMall
  class AdminCheckinsController < ::Admin::AdminController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    def index
      render json: {
        summary: summary_payload,
        trend: trend_payload,
        top_users: top_users_payload,
        recent_checkins: recent_checkins_payload,
      }
    end

    private

    def using_daily_checkin?
      defined?(::DiscourseDailyCheckin::DailyCheckin)
    end

    def relation
      using_daily_checkin? ? ::DiscourseDailyCheckin::DailyCheckin : ::PointsMallCheckin
    end

    def date_column
      using_daily_checkin? ? :checked_in_on : :checkin_date
    end

    def points_column
      using_daily_checkin? ? :points_awarded : :points_earned
    end

    def summary_payload
      today = Time.zone.today
      scoped = relation.all

      {
        total_checkins: scoped.count,
        total_points: scoped.sum(points_column),
        today_checkins: scoped.where(date_column => today).count,
        today_points: scoped.where(date_column => today).sum(points_column),
        active_users_7d: scoped.where("#{date_column} >= ?", today - 6).distinct.count(:user_id),
      }
    end

    def trend_payload
      end_date = Time.zone.today
      start_date = end_date - 6

      rows =
        relation
          .where("#{date_column} >= ? AND #{date_column} <= ?", start_date, end_date)
          .group(date_column)
          .pluck(
            date_column,
            Arel.sql("COUNT(*)"),
            Arel.sql("COALESCE(SUM(#{points_column}), 0)"),
          )

      by_date = rows.to_h { |date, count, points| [date, { count: count, points: points }] }

      (start_date..end_date).map do |date|
        data = by_date[date] || { count: 0, points: 0 }
        {
          date: date,
          checkins: data[:count],
          points: data[:points],
        }
      end
    end

    def top_users_payload
      rows =
        relation
          .where("#{date_column} >= ?", Time.zone.today - 29)
          .group(:user_id)
          .order(Arel.sql("COUNT(*) DESC"))
          .limit(10)
          .pluck(
            :user_id,
            Arel.sql("COUNT(*)"),
            Arel.sql("COALESCE(SUM(#{points_column}), 0)"),
          )

      user_ids = rows.map(&:first).compact
      users = ::User.where(id: user_ids).index_by(&:id)
      streak_by_user = streak_map(users)

      rows.map do |user_id, checkins, points|
        user = users[user_id]
        {
          user_id: user_id,
          username: user&.username,
          checkins: checkins,
          points: points,
          current_streak: streak_by_user[user_id] || 0,
        }
      end
    end

    def streak_map(users)
      return native_streak_map(users.keys) unless using_daily_checkin?

      users.transform_values do |user|
        ::DiscourseDailyCheckin::DailyCheckin.current_streak_for(user)
      end
    end

    def native_streak_map(user_ids)
      return {} if user_ids.blank?

      map = {}
      ::PointsMallCheckin
        .where(user_id: user_ids)
        .order(user_id: :asc, checkin_date: :desc, created_at: :desc)
        .each do |checkin|
          map[checkin.user_id] ||= checkin.streak_days
        end
      map
    end

    def recent_checkins_payload
      records = relation.order(date_column => :desc, created_at: :desc).limit(30)
      users = ::User.where(id: records.map(&:user_id).uniq).pluck(:id, :username).to_h

      records.map do |record|
        {
          id: record.id,
          user_id: record.user_id,
          username: users[record.user_id],
          checkin_date: record.public_send(date_column),
          points_earned: record.public_send(points_column),
          streak_days: using_daily_checkin? ? nil : record.streak_days,
          created_at: record.created_at,
        }
      end
    end
  end
end
