# frozen_string_literal: true

class CreatePointsMallLotteryEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_lottery_entries do |t|
      t.integer :user_id, null: false
      t.integer :lottery_id, null: false
      t.integer :points_spent, null: false
      t.string :prize_won
      t.boolean :claimed, default: false
      t.timestamps
    end

    add_index :points_mall_lottery_entries, :user_id
    add_index :points_mall_lottery_entries, :lottery_id
    add_index :points_mall_lottery_entries, :created_at
  end
end
