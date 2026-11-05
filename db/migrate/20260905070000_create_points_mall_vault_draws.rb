# frozen_string_literal: true

class CreatePointsMallVaultDraws < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_vault_draws do |t|
      t.integer :user_id, null: false
      t.integer :order_id, null: false
      t.date :draw_on, null: false
      t.jsonb :reward, null: false, default: {}
      t.string :delivery_state, null: false, default: "completed"
      t.integer :delivery_attempts, null: false, default: 0
      t.datetime :attempted_at
      t.text :last_error
      t.timestamps
    end
    add_index :points_mall_vault_draws, [:user_id, :draw_on], unique: true, name: "index_vault_draws_daily_user"
    add_index :points_mall_vault_draws, :order_id, unique: true
    add_index :points_mall_vault_draws, :delivery_state
    add_foreign_key :points_mall_vault_draws, :users
    add_foreign_key :points_mall_vault_draws, :points_mall_orders, column: :order_id
  end
end
