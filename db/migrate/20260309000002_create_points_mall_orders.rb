# frozen_string_literal: true

class CreatePointsMallOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_orders do |t|
      t.integer :user_id, null: false
      t.integer :product_id, null: false
      t.integer :points_spent, null: false
      t.string :status, null: false, default: 'pending'
      t.text :shipping_info
      t.text :notes
      t.timestamps
    end

    add_index :points_mall_orders, :user_id
    add_index :points_mall_orders, :product_id
    add_index :points_mall_orders, :status
    add_index :points_mall_orders, :created_at
  end
end
