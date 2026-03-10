# frozen_string_literal: true

class CreatePointsMallProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :points_cost, null: false
      t.integer :stock, default: 0
      t.string :product_type, null: false, default: 'virtual'
      t.string :image_url
      t.boolean :enabled, default: true
      t.integer :sort_order, default: 0
      t.timestamps
    end

    add_index :points_mall_products, :enabled
    add_index :points_mall_products, :sort_order
  end
end
