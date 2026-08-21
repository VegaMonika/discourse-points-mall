# frozen_string_literal: true

module DiscoursePointsMall
  class ProductSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :description,
               :points_cost,
               :stock,
               :product_type,
               :sort_order,
               :category,
               :featured,
               :badge_text,
               :image_url,
               :enabled,
               :price_brl,
               :external_url,
               :product_key,
               :is_makeup_card,
               :created_at

    def stock
      object.stock || -1
    end

    def category
      ::PointsMallProduct.has_category? ? object.category : nil
    end

    def featured
      ::PointsMallProduct.has_featured? ? object.featured : false
    end

    def badge_text
      ::PointsMallProduct.has_badge_text? ? object.badge_text : nil
    end

    def product_key
      object.respond_to?(:product_key) ? object.product_key : nil
    end

    def is_makeup_card
      object.respond_to?(:makeup_card?) && object.makeup_card?
    end
  end
end
