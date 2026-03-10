# frozen_string_literal: true

module DiscoursePointsMall
  class ProductsController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    def index
      ::PointsMallProduct.ensure_makeup_card!
      products = ::PointsMallProduct.ordered.to_a
      makeup_status = current_makeup_status

      visible_products =
        products.select do |product|
          product.makeup_card? || (product.enabled && (product.stock.nil? || product.stock.positive?))
        end

      products_payload =
        visible_products.map do |product|
          data = {
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
          }

          if product.makeup_card?
            data[:points_cost] = makeup_status[:next_price] || makeup_status[:prices]&.last || data[:points_cost]
            data[:purchaseable] = product.enabled && makeup_status[:can_purchase]
            data[:purchase_disabled_reason] = if !product.enabled
              "disabled"
            elsif !makeup_status[:can_purchase]
              "limit_reached"
            end
            data[:makeup_card] = makeup_status
          end

          data
        end

      render json: { products: products_payload }
    end

    def show
      product = ::PointsMallProduct.find(params[:id])
      render json: serialize_data(product, DiscoursePointsMall::ProductSerializer)
    end

    private

    def current_makeup_status
      return fallback_makeup_status unless defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?

      ::PointsMallMakeupCard.fetch_or_create_for(current_user.id).status_payload
    rescue StandardError
      fallback_makeup_status
    end

    def fallback_makeup_status
      {
        max_per_month: 3,
        purchased_count: 0,
        used_count: 0,
        available_count: 0,
        can_purchase: true,
        can_use: false,
        next_price: 1000,
        prices: [1000, 3000, 5000],
        expires_at: Time.zone.today.end_of_month,
      }
    end
  end
end
