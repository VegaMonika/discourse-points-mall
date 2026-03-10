# frozen_string_literal: true

class CreatePointsMallAddresses < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_addresses do |t|
      t.integer :user_id, null: false
      t.string :recipient_name, null: false
      t.string :phone, null: false
      t.string :address_line, null: false
      t.boolean :is_default, default: false, null: false
      t.timestamps
    end

    add_index :points_mall_addresses, :user_id
    add_index :points_mall_addresses, %i[user_id is_default]
  end
end
