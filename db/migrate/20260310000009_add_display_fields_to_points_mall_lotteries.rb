# frozen_string_literal: true

class AddDisplayFieldsToPointsMallLotteries < ActiveRecord::Migration[7.0]
  def change
    add_column :points_mall_lotteries, :image_url, :string
    add_column :points_mall_lotteries, :draw_mode, :string, null: false, default: "scheduled"
    add_column :points_mall_lotteries, :rules_text, :text

    add_index :points_mall_lotteries, :draw_mode
  end
end
