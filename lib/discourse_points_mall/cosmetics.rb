# frozen_string_literal: true

module ::DiscoursePointsMall
  module Cosmetics
    AVATAR_FRAME_KEY = /\Acosmetic_avatar_frame_(?<value>[a-z0-9_]+)_(?<days>\d+)d\z/.freeze

    STATIC_PRODUCTS = {
      "cosmetic_title_launch_trainer_30d" => {
        kind: "title",
        title: "开服训练家",
        value: "开服训练家",
        duration_days: 30,
      },
      "cosmetic_title_shiny_collector_30d" => {
        kind: "title",
        title: "闪光收藏家",
        value: "闪光收藏家",
        duration_days: 30,
      },
      "cosmetic_title_zenless_resident_30d" => {
        kind: "title",
        title: "绝区零居民",
        value: "绝区零居民",
        duration_days: 30,
      },
      "cosmetic_avatar_frame_neon_30d" => {
        kind: "avatar_frame",
        value: "neon_aqua",
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

    module_function

    def config_for(product_or_key)
      key = product_or_key.respond_to?(:product_key) ? product_or_key.product_key : product_or_key
      key = key.to_s
      return STATIC_PRODUCTS[key] if STATIC_PRODUCTS.key?(key)

      match = AVATAR_FRAME_KEY.match(key)
      return nil unless match

      {
        kind: "avatar_frame",
        value: match[:value],
        duration_days: match[:days].to_i,
      }
    end

    def configured?(product_or_key)
      config_for(product_or_key).present?
    end

    def product_for(kind, value)
      return nil unless defined?(::PointsMallProduct)

      ::PointsMallProduct.where(enabled: true).order(:sort_order, :id).detect do |product|
        config = config_for(product)
        config && config[:kind].to_s == kind.to_s && cosmetic_value(config).to_s == value.to_s
      end
    end

    def cosmetic_value(config)
      config[:value] || config[:title]
    end
  end
end
