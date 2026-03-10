# frozen_string_literal: true

module DiscoursePointsMall
  class OrdersController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    def index
      orders = ::PointsMallOrder.for_user(current_user.id).recent.includes(:product)
      render json: { orders: serialize_data(orders, DiscoursePointsMall::OrderSerializer) }
    end

    def create
      order = nil
      error = nil
      makeup_card = nil

      ::PointsMallOrder.transaction do
        locked_user = ::User.lock.find(current_user.id)
        product = ::PointsMallProduct.lock.find(params[:product_id])
        address_id = params[:address_id].presence
        address = nil
        shipping_info = params[:shipping_info].to_s.strip

        unless product.available?
          error = I18n.t("points_mall.errors.product_unavailable")
          raise ActiveRecord::Rollback
        end

        if product.makeup_card?
          unless defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?
            error = I18n.t("points_mall.errors.makeup_unavailable")
            raise ActiveRecord::Rollback
          end

          card = find_or_create_monthly_makeup_card(locked_user.id)
          unless card.can_purchase?
            error = I18n.t("points_mall.errors.makeup_purchase_limit_reached")
            raise ActiveRecord::Rollback
          end

          price = card.next_price
          if price.nil?
            error = I18n.t("points_mall.errors.makeup_purchase_limit_reached")
            raise ActiveRecord::Rollback
          end

          if locked_user.points_balance < price
            error = I18n.t("points_mall.errors.insufficient_points")
            raise ActiveRecord::Rollback
          end

          order =
            ::PointsMallOrder.create!(
              user_id: locked_user.id,
              product_id: product.id,
              points_spent: price,
              status: "completed",
            )

          unless DiscoursePointsMall::PointsManager.add_points!(
                   user: locked_user,
                   points: -price,
                   description: "积分商城购买补签卡",
                 )
            error = I18n.t("points_mall.errors.points_update_failed")
            raise ActiveRecord::Rollback
          end

          card.register_purchase!
          makeup_card = card.status_payload
          next
        end

        if product.product_type == "physical"
          if address_id.present?
            address = ::PointsMallAddress.for_user(locked_user.id).find_by(id: address_id)
            if address.nil?
              error = I18n.t("points_mall.errors.invalid_address")
              raise ActiveRecord::Rollback
            end
            shipping_info = address.full_text
          elsif shipping_info.blank?
            error = I18n.t("points_mall.errors.shipping_info_required")
            raise ActiveRecord::Rollback
          end
        end

        if locked_user.points_balance < product.points_cost
          error = I18n.t("points_mall.errors.insufficient_points")
          raise ActiveRecord::Rollback
        end

        order =
          ::PointsMallOrder.create!(
            user_id: locked_user.id,
            product_id: product.id,
            points_spent: product.points_cost,
            status: "pending",
            shipping_info: shipping_info.presence,
          )

        unless DiscoursePointsMall::PointsManager.add_points!(
                 user: locked_user,
                 points: -product.points_cost,
                 description: "积分商城兑换商品",
               )
          error = I18n.t("points_mall.errors.points_update_failed")
          raise ActiveRecord::Rollback
        end

        product.decrease_stock! if product.stock
      end

      if error
        render_json_error(error, status: 422)
      elsif order
        render json: {
          order: serialize_order(order),
          makeup_card: makeup_card,
        }
      else
        render_json_error(I18n.t("points_mall.errors.order_create_failed"), status: 422)
      end
    end

    def show
      order = ::PointsMallOrder.find(params[:id])

      unless order.user_id == current_user.id || current_user.staff?
        return render_json_error(I18n.t('points_mall.errors.unauthorized'), status: 403)
      end

      render json: serialize_data(order, DiscoursePointsMall::OrderSerializer)
    end

    private

    def find_or_create_monthly_makeup_card(user_id)
      month_key = ::PointsMallMakeupCard.month_key_for(Time.zone.today)
      card = ::PointsMallMakeupCard.lock.for_user_month(user_id, month_key).first
      return card if card

      ::PointsMallMakeupCard.create!(
        user_id: user_id,
        month_key: month_key,
        purchased_count: 0,
        used_count: 0,
      )
    rescue ActiveRecord::RecordNotUnique
      ::PointsMallMakeupCard.lock.for_user_month(user_id, month_key).first!
    end

    def serialize_order(order)
      product = order.product
      {
        id: order.id,
        user_id: order.user_id,
        product_id: order.product_id,
        points_spent: order.points_spent,
        status: order.status,
        shipping_info: order.shipping_info,
        notes: order.notes,
        created_at: order.created_at,
        product: {
          id: product.id,
          name: product.name,
          description: product.description,
          points_cost: product.points_cost,
          stock: product.stock || -1,
          product_type: product.product_type,
          image_url: product.image_url,
          enabled: product.enabled,
          product_key: (product.respond_to?(:product_key) ? product.product_key : nil),
          is_makeup_card: product.makeup_card?,
        },
      }
    end
  end
end
