# frozen_string_literal: true

class PointsMallMakeupCard < ActiveRecord::Base
  self.table_name = "points_mall_makeup_cards"

  MAX_PER_MONTH = 3
  PRICE_TIERS = [1000, 3000, 5000].freeze

  belongs_to :user

  validates :user_id, presence: true
  validates :month_key, presence: true
  validates :purchased_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_PER_MONTH }
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validates :month_key, uniqueness: { scope: :user_id }
  validate :used_count_not_exceed_purchased_count

  before_validation :normalize_month_key

  scope :for_user_month, ->(user_id, month_key) { where(user_id: user_id, month_key: month_key) }

  def self.month_key_for(date = Time.zone.today)
    date.to_date.beginning_of_month
  end

  def self.fetch_or_create_for(user_id, date = Time.zone.today)
    month_key = month_key_for(date)
    for_user_month(user_id, month_key).first_or_create!(purchased_count: 0, used_count: 0)
  end

  def can_purchase?
    purchased_count < MAX_PER_MONTH
  end

  def next_price
    return nil unless can_purchase?
    PRICE_TIERS[purchased_count]
  end

  def available_count
    [purchased_count - used_count, 0].max
  end

  def can_use?
    available_count.positive?
  end

  def register_purchase!
    raise ArgumentError, "monthly purchase limit reached" unless can_purchase?
    update!(purchased_count: purchased_count + 1)
  end

  def use_one!
    raise ArgumentError, "no available makeup cards" unless can_use?
    update!(used_count: used_count + 1)
  end

  def status_payload
    {
      month_key: month_key,
      max_per_month: MAX_PER_MONTH,
      purchased_count: purchased_count,
      used_count: used_count,
      available_count: available_count,
      can_purchase: can_purchase?,
      can_use: can_use?,
      next_price: next_price,
      prices: PRICE_TIERS,
      expires_at: month_key.end_of_month,
    }
  end

  private

  def normalize_month_key
    self.month_key = self.class.month_key_for(month_key || Time.zone.today)
  end

  def used_count_not_exceed_purchased_count
    return if used_count.to_i <= purchased_count.to_i
    errors.add(:used_count, "cannot exceed purchased_count")
  end
end
