# frozen_string_literal: true

class AddMakeupCardSupport < ActiveRecord::Migration[7.0]
  class Product < ActiveRecord::Base
    self.table_name = "points_mall_products"
  end

  def up
    add_column :points_mall_products, :product_key, :string unless column_exists?(:points_mall_products, :product_key)
    Product.reset_column_information

    unless index_exists?(:points_mall_products, :product_key, name: "index_points_mall_products_on_product_key")
      add_index :points_mall_products, :product_key, unique: true, where: "product_key IS NOT NULL", name: "index_points_mall_products_on_product_key"
    end

    create_table :points_mall_makeup_cards, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.date :month_key, null: false
      t.integer :purchased_count, null: false, default: 0
      t.integer :used_count, null: false, default: 0
      t.timestamps
    end

    unless index_exists?(:points_mall_makeup_cards, [:user_id, :month_key], name: "index_points_mall_makeup_cards_on_user_and_month")
      add_index :points_mall_makeup_cards, [:user_id, :month_key], unique: true, name: "index_points_mall_makeup_cards_on_user_and_month"
    end

    seed_makeup_card_product
  end

  def down
    remove_index :points_mall_makeup_cards, name: "index_points_mall_makeup_cards_on_user_and_month" if index_exists?(:points_mall_makeup_cards, [:user_id, :month_key], name: "index_points_mall_makeup_cards_on_user_and_month")
    drop_table :points_mall_makeup_cards, if_exists: true

    remove_index :points_mall_products, name: "index_points_mall_products_on_product_key" if index_exists?(:points_mall_products, :product_key, name: "index_points_mall_products_on_product_key")
    remove_column :points_mall_products, :product_key if column_exists?(:points_mall_products, :product_key)
  end

  private

  def seed_makeup_card_product
    return if Product.where(product_key: "makeup_card").exists?

    existing = Product.find_by(name: "补签卡")
    if existing
      existing.update_columns(
        product_key: "makeup_card",
        product_type: "virtual",
        points_cost: 1000,
        stock: nil,
        enabled: true,
        description: existing.description.presence || "用于补签本月漏签日期，每月最多购买与使用 3 次。未使用补签卡次月自动失效。",
        updated_at: Time.zone.now,
      )
      return
    end

    Product.create!(
      product_key: "makeup_card",
      name: "补签卡",
      description: "用于补签本月漏签日期，每月最多购买与使用 3 次。未使用补签卡次月自动失效。",
      points_cost: 1000,
      stock: nil,
      product_type: "virtual",
      enabled: true,
      sort_order: -100,
    )
  end
end
