# frozen_string_literal: true

class CreatePointsMallCheckins < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_checkins do |t|
      t.integer :user_id, null: false
      t.date :checkin_date, null: false
      t.integer :points_earned, null: false
      t.integer :streak_days, default: 1
      t.timestamps
    end

    add_index :points_mall_checkins, [:user_id, :checkin_date], unique: true
    add_index :points_mall_checkins, :user_id
    add_index :points_mall_checkins, :checkin_date
  end
end
