# frozen_string_literal: true

class PointsMallVaultDraw < ActiveRecord::Base
  self.table_name = "points_mall_vault_draws"
  belongs_to :user
  belongs_to :order, class_name: "PointsMallOrder"
  validates :draw_on, :reward, presence: true
  validates :delivery_state, inclusion: { in: %w[completed pending delivering waiting_account needs_review] }
end
