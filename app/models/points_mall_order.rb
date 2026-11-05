# frozen_string_literal: true

class PointsMallOrder < ActiveRecord::Base
  self.table_name = 'points_mall_orders'

  belongs_to :user
  belongs_to :product, class_name: 'PointsMallProduct'

  validates :user_id, presence: true
  validates :product_id, presence: true
  validates :points_spent, presence: true, numericality: { greater_than: 0 }, unless: :star_vault_reward?
  validates :points_spent, numericality: { equal_to: 0 }, if: :star_vault_reward?
  validates :status, presence: true, inclusion: { in: %w[pending processing completed cancelled] }

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }

  def star_vault_reward?
    data = JSON.parse(notes.to_s)
    data.is_a?(Hash) && data["source"] == "star_vault" &&
      %w[processing completed].include?(status) &&
      DiscoursePointsMall::StarVault::POOL.any? { |entry| entry[:key] == product&.product_key }
  rescue JSON::ParserError
    false
  end
end
