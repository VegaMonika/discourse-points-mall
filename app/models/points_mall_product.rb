# frozen_string_literal: true

class PointsMallProduct < ActiveRecord::Base
  self.table_name = 'points_mall_products'

  MAKEUP_CARD_KEY = "makeup_card"

  has_many :orders, class_name: 'PointsMallOrder', foreign_key: 'product_id'

  validates :name, presence: true
  validates :points_cost, presence: true, numericality: { greater_than: 0 }
  validates :product_type, presence: true, inclusion: { in: %w[virtual physical] }
  validates :product_key, uniqueness: true, allow_nil: true, if: -> { self.class.has_product_key? }

  scope :enabled, -> { where(enabled: true) }
  scope :in_stock, -> { where('stock > 0 OR stock IS NULL') }
  scope :ordered, -> { order(sort_order: :asc, created_at: :desc) }

  def self.has_product_key?
    column_names.include?("product_key")
  end

  def self.ensure_makeup_card!
    return unless has_product_key?
    return if where(product_key: MAKEUP_CARD_KEY).exists?

    create!(
      product_key: MAKEUP_CARD_KEY,
      name: "补签卡",
      description: "用于补签本月漏签日期，每月最多购买与使用 3 次。未使用补签卡次月自动失效。",
      points_cost: 1000,
      stock: nil,
      product_type: "virtual",
      enabled: true,
      sort_order: -100,
    )
  rescue StandardError => e
    Rails.logger.warn("[points-mall] ensure_makeup_card! failed: #{e.class} #{e.message}")
  end

  def makeup_card?
    self.class.has_product_key? && product_key == MAKEUP_CARD_KEY
  end

  def available?
    enabled && (stock.nil? || stock > 0)
  end

  def decrease_stock!
    return if stock.nil?
    update!(stock: stock - 1)
  end
end
