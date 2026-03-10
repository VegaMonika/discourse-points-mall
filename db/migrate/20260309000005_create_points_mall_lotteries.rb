# frozen_string_literal: true

class CreatePointsMallLotteries < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_lotteries do |t|
      t.string :name, null: false
      t.text :description
      t.integer :points_cost, null: false
      t.text :prizes
      t.boolean :enabled, default: true
      t.datetime :start_date
      t.datetime :end_date
      t.timestamps
    end

    add_index :points_mall_lotteries, :enabled
  end
end
