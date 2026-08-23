# frozen_string_literal: true

require "json"

module DiscoursePointsMall
  class InventoryController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    KIND_FIELDS = {
      "title" => {
        value: "jn_cosmetic_title",
        expires: "jn_cosmetic_title_expires_at",
      },
      "avatar_frame" => {
        value: "jn_cosmetic_avatar_frame",
        expires: "jn_cosmetic_avatar_frame_expires_at",
      },
      "card_border" => {
        value: "jn_cosmetic_card_border",
        expires: "jn_cosmetic_card_border_expires_at",
      },
      "profile_background" => {
        value: "jn_cosmetic_profile_background",
        expires: "jn_cosmetic_profile_background_expires_at",
      },
      "post_signature" => {
        value: "jn_cosmetic_post_signature",
        expires: "jn_cosmetic_post_signature_expires_at",
      },
      "svip_glow" => {
        value: "jn_cosmetic_svip_glow",
        expires: "jn_cosmetic_svip_glow_expires_at",
      },
      "theme_skin" => {
        value: "jn_cosmetic_theme_skin",
        expires: "jn_cosmetic_theme_skin_expires_at",
      },
    }.freeze

    KIND_LABELS = {
      "title" => "称号",
      "avatar_frame" => "头像框",
      "card_border" => "名片边框",
      "profile_background" => "个人页背景",
      "post_signature" => "发帖小尾巴",
      "svip_glow" => "SVIP 特效",
      "theme_skin" => "主题 UI",
    }.freeze

    def index
      render json: inventory_payload
    end

    def equip
      order = cosmetic_order(params[:order_id])
      return render_json_error("未找到该装饰", status: 404) unless order

      config = DiscoursePointsMall::Cosmetics.config_for(order.product)
      return render_json_error("该装饰已过期", status: 422) if expired_order?(order, config)

      apply_cosmetic!(current_user, config, expires_at_for(order, config))
      render json: inventory_payload
    rescue StandardError => e
      Rails.logger.warn("[points-mall] inventory equip failed: #{e.class}: #{e.message}")
      render_json_error("装备失败，请稍后再试", status: 422)
    end

    def unequip
      kind = params[:kind].to_s
      return render_json_error("不支持该装饰类型", status: 422) unless KIND_FIELDS.key?(kind)

      remove_cosmetic!(current_user, kind)
      render json: inventory_payload
    rescue StandardError => e
      Rails.logger.warn("[points-mall] inventory unequip failed: #{e.class}: #{e.message}")
      render_json_error("卸下失败，请稍后再试", status: 422)
    end

    private

    def inventory_payload
      orders =
        ::PointsMallOrder
          .where(user_id: current_user.id, status: "completed")
          .includes(:product)
          .select { |order| DiscoursePointsMall::Cosmetics.configured?(order.product) }

      items =
        orders.map { |order| item_payload(order) }
          .sort_by { |item| [item[:expired] ? 1 : 0, item[:equipped] ? 0 : 1, -Time.zone.parse(item[:granted_at]).to_i] }

      {
        inventory: {
          items: items,
          equipped: equipped_payload,
          theme_skin_ticket_count: theme_skin_ticket_count(orders),
        },
      }
    end

    def item_payload(order)
      product = order.product
      config = DiscoursePointsMall::Cosmetics.config_for(product)
      expires_at = expires_at_for(order, config)
      expired = expires_at.present? && expires_at <= Time.zone.now
      value = cosmetic_value(config)

      {
        order_id: order.id,
        product_id: product.id,
        product_key: product.product_key,
        name: product.name,
        description: product.description,
        image_url: product.image_url,
        kind: config[:kind],
        kind_label: KIND_LABELS[config[:kind]] || config[:kind],
        value: value,
        display_value: display_value_for(config[:kind], value, product.name),
        preview_class: preview_class_for(config[:kind], value),
        granted_at: granted_at_for(order).iso8601,
        expires_at: expires_at&.iso8601,
        granted_display: display_time(granted_at_for(order)),
        expires_display: display_time(expires_at),
        remaining_text: remaining_text(expires_at),
        expired: expired,
        equipped: !expired && equipped?(config[:kind], value),
        equippable: !expired,
      }
    end

    def theme_skin_ticket_count(orders)
      order_count =
        orders.count do |order|
          DiscoursePointsMall::Cosmetics.config_for(order.product)&.dig(:kind) == "theme_skin"
        end

      [current_user.custom_fields["jn_theme_skin_ticket_count"].to_i, order_count].max
    end

    def equipped_payload
      KIND_FIELDS.each_with_object({}) do |(kind, fields), payload|
        value = current_user.custom_fields[fields[:value]].presence
        next unless value

        payload[kind] = {
          kind: kind,
          kind_label: KIND_LABELS[kind] || kind,
          value: value,
          display_value: display_value_for(kind, value),
          preview_class: preview_class_for(kind, value),
          image_url: cosmetic_image_url(kind, value),
          expires_at: current_user.custom_fields[fields[:expires]].presence,
          expires_display: display_time(parse_time(current_user.custom_fields[fields[:expires]].presence)),
          remaining_text: remaining_text(parse_time(current_user.custom_fields[fields[:expires]].presence)),
        }
      end
    end

    def cosmetic_order(order_id)
      return nil if order_id.blank?

      ::PointsMallOrder
        .where(user_id: current_user.id, status: "completed")
        .includes(:product)
        .find_by(id: order_id)
        .tap do |order|
          return nil unless order && DiscoursePointsMall::Cosmetics.configured?(order.product)
        end
    end

    def order_notes(order)
      JSON.parse(order.notes.to_s.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def granted_at_for(order)
      Time.zone.parse(order_notes(order)["granted_at"].to_s) rescue order.created_at
    end

    def expires_at_for(order, config)
      note_expires = order_notes(order)["expires_at"].presence
      return Time.zone.parse(note_expires) if note_expires
      return nil unless config[:duration_days]

      order.created_at + config[:duration_days].days
    rescue StandardError
      nil
    end

    def expired_order?(order, config)
      expires_at = expires_at_for(order, config)
      expires_at.present? && expires_at <= Time.zone.now
    end

    def cosmetic_value(config)
      config[:value] || config[:title]
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue StandardError
      nil
    end

    def display_time(time)
      return nil unless time

      time.in_time_zone.strftime("%Y-%m-%d %H:%M")
    end

    def remaining_text(time)
      return nil unless time

      seconds = (time - Time.zone.now).to_i
      return "已过期" if seconds <= 0

      days = seconds / 1.day
      return "剩余 #{days} 天" if days.positive?

      hours = [seconds / 1.hour, 1].max
      "剩余 #{hours} 小时"
    end

    def display_value_for(kind, value, fallback = nil)
      named_product = DiscoursePointsMall::Cosmetics.product_for(kind, value)
      return fallback if fallback.present?
      return named_product.name if named_product

      case value.to_s
      when "neon_aqua"
        "霓虹水蓝"
      when "chibi_blue_heart"
        "蓝心绮梦"
      when "holo_gold"
        "全息金"
      when "zenless_blue"
        "新艾利都夜景"
      when "sakura_tail"
        "樱花轨迹"
      when "aurora"
        "极光发光名牌"
      when "starrail_neon"
        "星轨霓虹"
      else
        value.to_s.tr("_", " ")
      end
    end

    def preview_class_for(kind, value)
      "inventory-preview-#{kind.to_s.dasherize}-#{value.to_s.dasherize}"
    end

    def cosmetic_image_url(kind, value)
      DiscoursePointsMall::Cosmetics.product_for(kind, value)&.image_url
    end

    def equipped?(kind, value)
      fields = KIND_FIELDS[kind]
      return false unless fields

      current_user.custom_fields[fields[:value]].to_s == value.to_s
    end

    def apply_cosmetic!(user, config, expires_at)
      kind = config[:kind]
      value = cosmetic_value(config)
      fields = KIND_FIELDS[kind]
      raise "unsupported cosmetic kind" unless fields

      if kind == "title"
        if user.custom_fields["jn_cosmetic_title"].blank?
          user.custom_fields["jn_previous_title_before_cosmetic"] = user.title.to_s
        end
        user.title = value
      end

      user.custom_fields[fields[:value]] = value
      user.custom_fields[fields[:expires]] = expires_at&.iso8601.to_s
      user.save_custom_fields(true)
      user.save!
    end

    def remove_cosmetic!(user, kind)
      fields = KIND_FIELDS[kind]
      raise "unsupported cosmetic kind" unless fields

      if kind == "title"
        user.title = user.custom_fields["jn_previous_title_before_cosmetic"].to_s.presence
        user.custom_fields.delete("jn_previous_title_before_cosmetic")
        user.save!
      end

      user.custom_fields.delete(fields[:value])
      user.custom_fields.delete(fields[:expires])
      user.save_custom_fields(true)
    end
  end
end
