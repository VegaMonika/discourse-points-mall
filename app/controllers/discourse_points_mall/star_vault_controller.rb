# frozen_string_literal: true

module DiscoursePointsMall
  class StarVaultController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME
    before_action :ensure_logged_in

    def show
      render json: StarVault.status(current_user)
    end

    def create
      payload = StarVault.open!(current_user)
      Jobs.enqueue(:points_mall_vault_delivery, draw_id: payload[:result]["draw_id"]) if payload[:result]["delivery_state"] == "pending"
      render json: payload
    rescue StarVault::Unavailable => e
      render_json_error(e.message, status: 422)
    end

    def retry_delivery
      draw = PointsMallVaultDraw.find_by!(id: params[:id], user_id: current_user.id)
      draw.with_lock do
        draw.update!(delivery_state: "pending", last_error: nil) if draw.delivery_state == "waiting_account"
      end
      Jobs.enqueue(:points_mall_vault_delivery, draw_id: draw.id) if draw.delivery_state == "pending"
      render json: { result: StarVault.present(draw) }
    end
  end
end
