# frozen_string_literal: true

module DiscoursePointsMall
  class OrderSerializer < ApplicationSerializer
    attributes :id, :user_id, :product_id, :points_spent, :status, :shipping_info, :notes, :created_at
    has_one :product, serializer: DiscoursePointsMall::ProductSerializer, embed: :objects
  end
end
