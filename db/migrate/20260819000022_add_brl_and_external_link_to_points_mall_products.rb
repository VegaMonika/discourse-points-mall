# frozen_string_literal: true

class AddBrlAndExternalLinkToPointsMallProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :points_mall_products, :price_brl, :decimal, precision: 10, scale: 2
    add_column :points_mall_products, :external_url, :string
  end
end
