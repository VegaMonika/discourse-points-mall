# frozen_string_literal: true

module DiscoursePointsMall
  class ProductSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :description,
               :points_cost,
               :stock,
               :product_type,
               :image_url,
               :enabled,
               :product_key,
               :is_makeup_card

    def stock
      object.stock || -1
    end

    def product_key
      object.respond_to?(:product_key) ? object.product_key : nil
    end

    def is_makeup_card
      object.respond_to?(:makeup_card?) && object.makeup_card?
    end
  end
end
