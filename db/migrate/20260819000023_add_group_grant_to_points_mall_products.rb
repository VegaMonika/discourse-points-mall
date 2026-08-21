# frozen_string_literal: true

class AddGroupGrantToPointsMallProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :points_mall_products, :grant_group_id, :integer
    add_column :points_mall_products, :grant_duration_days, :integer
  end
end
