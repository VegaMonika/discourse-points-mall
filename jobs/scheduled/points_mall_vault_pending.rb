# frozen_string_literal: true
module Jobs
  class PointsMallVaultPending < ::Jobs::Scheduled
    every 5.minutes
    def execute(_args)
      return unless PointsMallVaultDraw.table_exists?
      PointsMallVaultDraw.where(delivery_state: "pending").order(:id).limit(50).pluck(:id).each do |id|
        Jobs.enqueue(:points_mall_vault_delivery, draw_id: id)
      end
    end
  end
end
