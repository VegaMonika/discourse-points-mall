# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"

module DiscoursePointsMall
  class OrdersController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    GAME_VOUCHERS = {
      "pokerogue_voucher_regular" => { voucher_type: 0, count: 1, label: "Regular Voucher" },
      "pokerogue_voucher_plus" => { voucher_type: 1, count: 1, label: "Plus Voucher" },
      "pokerogue_voucher_premium" => { voucher_type: 2, count: 1, label: "Premium Voucher" },
      "pokerogue_voucher_golden" => { voucher_type: 3, count: 1, label: "Golden Voucher" },
    }.freeze

    # 网盘流量商品：从 product_key 自动解析，无需改代码即可新增商品
    #   netdisk_traffic_1gb        => 1GB 永久
    #   netdisk_traffic_5gb        => 5GB 永久
    #   netdisk_traffic_500mb      => 500MB 永久
    #   netdisk_traffic_10gb_30d   => 10GB，30 天有效
    NETDISK_TRAFFIC_KEY = /\Anetdisk_traffic_(\d+)(gb|mb)(?:_(\d+)d)?\z/i

    COSMETIC_PRODUCTS = {
      "cosmetic_title_launch_trainer_30d" => {
        kind: "title",
        title: "开服训练家",
        duration_days: 30,
      },
      "cosmetic_title_shiny_collector_30d" => {
        kind: "title",
        title: "闪光收藏家",
        duration_days: 30,
      },
      "cosmetic_title_zenless_resident_30d" => {
        kind: "title",
        title: "绝区零居民",
        duration_days: 30,
      },
      "cosmetic_avatar_frame_neon_30d" => {
        kind: "avatar_frame",
        value: "neon_aqua",
        duration_days: 30,
      },
      "cosmetic_avatar_frame_chibi_blue_heart_30d" => {
        kind: "avatar_frame",
        value: "chibi_blue_heart",
        duration_days: 30,
      },
      "cosmetic_card_border_holo_30d" => {
        kind: "card_border",
        value: "holo_gold",
        duration_days: 30,
      },
      "cosmetic_profile_bg_zzz_30d" => {
        kind: "profile_background",
        value: "zenless_blue",
        duration_days: 30,
      },
      "cosmetic_post_signature_sakura_30d" => {
        kind: "post_signature",
        value: "sakura_tail",
        duration_days: 30,
      },
      "cosmetic_svip_glow_30d" => {
        kind: "svip_glow",
        value: "aurora",
        duration_days: 30,
        requires_group: "SVIP",
      },
      "cosmetic_theme_skin_ticket" => {
        kind: "theme_skin",
        value: "starrail_neon",
        duration_days: nil,
      },
    }.freeze

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

        if game_voucher_product?(product)
          price = product.points_cost

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
                   description: "???????????",
                 )
            error = I18n.t("points_mall.errors.points_update_failed")
            raise ActiveRecord::Rollback
          end

          granted, grant_error = grant_game_voucher!(locked_user, product, order)
          unless granted
            error = grant_error
            raise ActiveRecord::Rollback
          end

          product.decrease_stock! if product.stock
          next
        end

        if netdisk_traffic_product?(product)
          price = product.points_cost

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
                   description: "积分商城兑换网盘流量",
                 )
            error = I18n.t("points_mall.errors.points_update_failed")
            raise ActiveRecord::Rollback
          end

          granted, grant_error = grant_netdisk_traffic!(locked_user, product, order)
          unless granted
            error = grant_error
            raise ActiveRecord::Rollback
          end

          product.decrease_stock! if product.stock
          next
        end

        if cosmetic_product?(product)
          price = product.points_cost

          if locked_user.points_balance < price
            error = I18n.t("points_mall.errors.insufficient_points")
            raise ActiveRecord::Rollback
          end

          granted, grant_error, grant_payload = grant_cosmetic!(locked_user, product)
          unless granted
            error = grant_error
            raise ActiveRecord::Rollback
          end

          order =
            ::PointsMallOrder.create!(
              user_id: locked_user.id,
              product_id: product.id,
              points_spent: price,
              status: "completed",
              notes: grant_payload.to_json,
            )

          unless DiscoursePointsMall::PointsManager.add_points!(
                   user: locked_user,
                   points: -price,
                   description: "积分商城兑换身份装饰",
                 )
            error = I18n.t("points_mall.errors.points_update_failed")
            raise ActiveRecord::Rollback
          end

          product.decrease_stock! if product.stock
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

    def game_voucher_product?(product)
      product.respond_to?(:product_key) && GAME_VOUCHERS.key?(product.product_key)
    end

    def game_voucher_config(product)
      GAME_VOUCHERS[product.product_key]
    end

    def cosmetic_product?(product)
      product.respond_to?(:product_key) && COSMETIC_PRODUCTS.key?(product.product_key)
    end

    def cosmetic_config(product)
      COSMETIC_PRODUCTS[product.product_key]
    end

    def cosmetic_expires_at(config)
      days = config[:duration_days]
      return nil unless days

      days.days.from_now
    end

    def grant_cosmetic!(user, product)
      config = cosmetic_config(product)
      return [false, "装饰商品配置不存在", nil] unless config

      required_group = config[:requires_group]
      if required_group.present?
        group = ::Group.find_by(name: required_group)
        unless group && ::GroupUser.exists?(group_id: group.id, user_id: user.id)
          return [false, "该商品仅限 #{required_group} 用户兑换", nil]
        end
      end

      expires_at = cosmetic_expires_at(config)
      payload = {
        product_key: product.product_key,
        kind: config[:kind],
        value: config[:value] || config[:title],
        title: config[:title],
        granted_at: Time.zone.now.iso8601,
        expires_at: expires_at&.iso8601,
      }.compact

      case config[:kind]
      when "title"
        user.custom_fields["jn_previous_title_before_cosmetic"] = user.title.to_s
        user.title = config[:title]
        user.custom_fields["jn_cosmetic_title"] = config[:title]
        user.custom_fields["jn_cosmetic_title_expires_at"] = expires_at&.iso8601.to_s
      when "avatar_frame"
        user.custom_fields["jn_cosmetic_avatar_frame"] = config[:value]
        user.custom_fields["jn_cosmetic_avatar_frame_expires_at"] = expires_at&.iso8601.to_s
      when "card_border"
        user.custom_fields["jn_cosmetic_card_border"] = config[:value]
        user.custom_fields["jn_cosmetic_card_border_expires_at"] = expires_at&.iso8601.to_s
      when "profile_background"
        user.custom_fields["jn_cosmetic_profile_background"] = config[:value]
        user.custom_fields["jn_cosmetic_profile_background_expires_at"] = expires_at&.iso8601.to_s
      when "post_signature"
        user.custom_fields["jn_cosmetic_post_signature"] = config[:value]
        user.custom_fields["jn_cosmetic_post_signature_expires_at"] = expires_at&.iso8601.to_s
      when "svip_glow"
        user.custom_fields["jn_cosmetic_svip_glow"] = config[:value]
        user.custom_fields["jn_cosmetic_svip_glow_expires_at"] = expires_at&.iso8601.to_s
      when "theme_skin"
        user.custom_fields["jn_cosmetic_theme_skin"] = config[:value]
        user.custom_fields["jn_cosmetic_theme_skin_expires_at"] = expires_at&.iso8601.to_s
        current_count = user.custom_fields["jn_theme_skin_ticket_count"].to_i
        user.custom_fields["jn_theme_skin_ticket_count"] = (current_count + 1).to_s
      else
        return [false, "暂不支持该装饰类型", nil]
      end

      user.save_custom_fields(true)
      user.save!
      [true, nil, payload]
    rescue StandardError => e
      Rails.logger.warn("[points-mall] cosmetic grant failed: #{e.class}: #{e.message}")
      [false, "装饰发放失败，请稍后再试", nil]
    end

    def netdisk_traffic_config(product)
      return nil unless product.respond_to?(:product_key)
      m = NETDISK_TRAFFIC_KEY.match(product.product_key.to_s)
      return nil unless m
      amount = m[1].to_i
      mb = m[2].downcase == "gb" ? amount * 1024 : amount
      return nil if mb <= 0
      { mb: mb, valid_days: m[3].to_i }
    end

    def netdisk_traffic_product?(product)
      !netdisk_traffic_config(product).nil?
    end

    def netdisk_grant_secret
      path = "/shared/netdisk_redeem_secret"
      return nil unless File.exist?(path)

      File.read(path).strip.presence
    end

    def grant_netdisk_traffic!(user, product, order)
      config = netdisk_traffic_config(product)
      return [false, "商品配置无效"] if config.nil?
      secret = netdisk_grant_secret
      return [false, "流量发货服务未配置"] if secret.blank?

      payload = {
        external_id: "points_mall_order:#{order.id}",
        discourse_id: user.id.to_s,
        mb: config[:mb],
        valid_days: config[:valid_days],
        timestamp: Time.now.to_i,
      }
      signing_payload = [
        payload[:external_id],
        payload[:discourse_id],
        payload[:mb],
        payload[:valid_days],
        payload[:timestamp],
      ].join(":")
      payload[:signature] = Base64.urlsafe_encode64(
        OpenSSL::HMAC.digest("SHA256", secret, signing_payload),
        padding: false,
      )

      uri = URI("https://172.17.0.1/sso/points-grant")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = 5
      http.read_timeout = 15

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Host"] = "pan.justnainai.com"
      request.body = payload.to_json

      response = http.request(request)
      return [true, nil] if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("[points-mall] netdisk traffic grant failed: #{response.code} #{response.body}")
      case response.code.to_i
      when 409
        [false, "该订单已发过货，请勿重复兑换"]
      else
        [false, "流量发放失败，请稍后再试或联系站长"]
      end
    rescue StandardError => e
      Rails.logger.warn("[points-mall] netdisk traffic grant error: #{e.class}: #{e.message}")
      [false, "流量发放失败，请稍后再试或联系站长"]
    end

    def game_voucher_secret
      path = "/shared/game_voucher_redeem_secret"
      return nil unless File.exist?(path)

      File.read(path).strip.presence
    end

    def grant_game_voucher!(user, product, order)
      config = game_voucher_config(product)
      secret = game_voucher_secret
      return [false, "?????????"] if secret.blank?

      payload = {
        external_id: "points_mall_order:#{order.id}",
        discourse_id: user.id.to_s,
        voucher_type: config[:voucher_type],
        count: config[:count],
        timestamp: Time.now.to_i,
      }
      signing_payload = [
        payload[:external_id],
        payload[:discourse_id],
        payload[:voucher_type],
        payload[:count],
        payload[:timestamp],
      ].join(":")
      payload[:signature] = Base64.urlsafe_encode64(
        OpenSSL::HMAC.digest("SHA256", secret, signing_payload),
        padding: false,
      )

      uri = URI("https://172.17.0.1/api/community/grant-voucher")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = 5
      http.read_timeout = 15

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Host"] = "game.justnainai.com"
      request.body = payload.to_json

      response = http.request(request)
      return [true, nil] if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("[points-mall] game voucher grant failed: #{response.code} #{response.body}")
      case response.code.to_i
      when 404
        [false, "???????????????????????"]
      when 409
        [false, "???????????????????????"]
      else
        [false, "?????????????"]
      end
    rescue StandardError => e
      Rails.logger.warn("[points-mall] game voucher grant error: #{e.class}: #{e.message}")
      [false, "?????????????"]
    end

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
          category: (::PointsMallProduct.has_category? ? product.category : nil),
          featured: (::PointsMallProduct.has_featured? ? product.featured : false),
          badge_text: (::PointsMallProduct.has_badge_text? ? product.badge_text : nil),
          image_url: product.image_url,
          enabled: product.enabled,
          product_key: (product.respond_to?(:product_key) ? product.product_key : nil),
          is_makeup_card: product.makeup_card?,
        },
      }
    end
  end
end
