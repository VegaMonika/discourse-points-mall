# frozen_string_literal: true

class PointsMallOrder < ActiveRecord::Base
  self.table_name = 'points_mall_orders'

  belongs_to :user
  belongs_to :product, class_name: 'PointsMallProduct'

  validates :user_id, presence: true
  validates :product_id, presence: true
  validates :points_spent, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed cancelled] }

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
end
