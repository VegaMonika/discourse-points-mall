# frozen_string_literal: true

module DiscoursePointsMall
  class CheckinSerializer < ApplicationSerializer
    attributes :id, :user_id, :checkin_date, :points_earned, :streak_days, :created_at
  end
end
