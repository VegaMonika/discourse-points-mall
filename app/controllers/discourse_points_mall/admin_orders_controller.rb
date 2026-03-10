# frozen_string_literal: true

module DiscoursePointsMall
  class AdminOrdersController < ::Admin::AdminController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :find_order, only: %i[update]

    def index
      orders = ::PointsMallOrder.includes(:user, :product).order(created_at: :desc).limit(200)
      render json: { orders: orders.map { |order| serialize_order(order) } }
    end

    def update
      if @order.update(permitted_order_params)
        render json: { order: serialize_order(@order) }
      else
        render_json_error(@order.errors.full_messages.join(", "), status: 422)
      end
    end

    private

    def find_order
      @order = ::PointsMallOrder.includes(:user, :product).find(params[:id])
    end

    def permitted_order_params
      params.permit(:status, :notes).to_h
    end

    def serialize_order(order)
      user = order.user
      product = order.product

      {
        id: order.id,
        user_id: order.user_id,
        username: user&.username,
        avatar_template: user&.avatar_template,
        is_admin: user&.admin || false,
        is_moderator: user&.moderator || false,
        is_staff: user&.staff? || false,
        trust_level: user&.trust_level || 0,
        product_id: order.product_id,
        product_name: product&.name,
        product_type: product&.product_type,
        product_image_url: product&.image_url,
        points_spent: order.points_spent,
        status: order.status,
        shipping_info: order.shipping_info,
        notes: order.notes,
        created_at: order.created_at,
      }
    end
  end
end
