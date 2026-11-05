# frozen_string_literal: true
require "net/http"
require "json"
require "base64"
require "openssl"

module DiscoursePointsMall
  class StarVaultDelivery
    def self.perform(draw_id)
      draw = PointsMallVaultDraw.find_by(id: draw_id)
      return unless draw
      claimed = false
      draw.with_lock do
        if draw.delivery_state == "pending"
          draw.update!(delivery_state: "delivering", attempted_at: Time.current, delivery_attempts: draw.delivery_attempts + 1)
          claimed = true
        end
      end
      return unless claimed
      outcome, message = send_reward(draw)
      draw.with_lock do
        draw.update!(delivery_state: outcome, last_error: message)
        draw.order.update!(status: "completed") if outcome == "completed"
      end
    end

    def self.send_reward(draw)
      reward = draw.reward
      common = { external_id: "points_mall_vault:#{draw.id}:order:#{draw.order_id}", discourse_id: draw.user_id.to_s }
      if reward["kind"] == "game"
        endpoint = "https://game.justnainai.com/api/community/grant-voucher"
        secret_path = "/shared/game_voucher_redeem_secret"
        payload = common.merge(voucher_type: reward.fetch("voucher_type"), count: reward.fetch("count"), timestamp: Time.now.to_i)
      elsif reward["kind"] == "traffic"
        endpoint = "https://pan.justnainai.com/sso/points-grant"
        secret_path = "/shared/netdisk_redeem_secret"
        payload = common.merge(mb: reward.fetch("mb"), valid_days: reward.fetch("valid_days"), timestamp: Time.now.to_i)
      else
        return ["needs_review", "奖励类型需要站长核对。"]
      end
      secret = File.read(secret_path).strip
      return ["needs_review", "发奖服务未配置，请联系站长。"] if secret.empty?
      signature = OpenSSL::HMAC.digest("SHA256", secret, payload.values.join(":"))
      payload[:signature] = Base64.urlsafe_encode64(signature, padding: false)
      uri = URI(endpoint)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20, write_timeout: 10) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json
        http.request(request)
      end
      interpret(reward["kind"], response.code.to_i, JSON.parse(response.body))
    rescue StandardError => e
      Rails.logger.warn("[star-vault] delivery needs review draw=#{draw.id} error=#{e.class}")
      ["needs_review", "到账状态未确认，奖励记录已保留，请联系站长核对，勿重复发放。"]
    end

    def self.interpret(kind, code, body)
      if kind == "game" && [404, 409].include?(code)
        return ["waiting_account", "请先用论坛账号进入游戏、创建一次存档，再点击补领。"]
      end
      # Existing services can mark an ID before crediting it. A duplicate is not proof of delivery.
      if (200...300).cover?(code) && !body["duplicate"] && (body["success"] == true || body["ok"] == true)
        return ["completed", nil]
      end
      ["needs_review", "发奖结果需要核对，奖励记录已保留，请联系站长并提供订单号。"]
    end
  end
end
