# frozen_string_literal: true

module DiscoursePointsMall
  class AdminOrdersController < ::Admin::AdminController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :find_order, only: %i[update refund]

    def index
      orders = ::PointsMallOrder.includes(:user, :product).order(created_at: :desc).limit(300)
      render json: { orders: orders.map { |order| serialize_order(order) } }
    end

    def update
      if @order.update(permitted_order_params)
        render json: { order: serialize_order(@order) }
      else
        render_json_error(@order.errors.full_messages.join(", "), status: 422)
      end
    end

    def refund
      if @order.status == "refunded"
        return render_json_error("Este pedido já foi reembolsado anteriormente.", status: 422)
      end

      ActiveRecord::Base.transaction do
        user = @order.user
        points_spent = @order.points_spent.to_i

        if user && points_spent > 0
          user.points_balance = user.points_balance.to_i + points_spent
          user.save!

          ::PointsMallLedger.create!(
            user_id: user.id,
            points_change: points_spent,
            balance_after: user.points_balance,
            category: "refund",
            description: "Reembolso do pedido ##{@order.id} (#{@order.product&.name || 'Produto'})",
            source_type: "PointsMallOrder",
            source_id: @order.id
          )
        end

        product = @order.product
        if product
          if product.respond_to?(:group_grant_id) && product.group_grant_id.present?
            group = Group.find_by(id: product.group_grant_id)
            group&.remove(user) if user
          end

          if product.stock.to_i >= 0
            product.increment!(:stock)
          end
        end

        refund_note = "[Reembolsado em #{Time.zone.now.strftime('%d/%m/%Y %H:%M')} por #{current_user.username}]"
        new_notes = [@order.notes.to_s.presence, refund_note].compact.join("\n")

        @order.update!(
          status: "refunded",
          notes: new_notes
        )
      end

      render json: { order: serialize_order(@order) }
    rescue StandardError => e
      Rails.logger.error("[points-mall] refund failed for order #{@order&.id}: #{e.message}")
      render_json_error("Falha ao processar reembolso: #{e.message}", status: 422)
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
