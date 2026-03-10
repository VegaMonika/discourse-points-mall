# frozen_string_literal: true

class PointsMallAddress < ActiveRecord::Base
  self.table_name = "points_mall_addresses"

  MAX_ADDRESSES_PER_USER = 3

  belongs_to :user

  validates :user_id, presence: true
  validates :recipient_name, presence: true, length: { maximum: 64 }
  validates :phone, presence: true, length: { maximum: 32 }
  validates :address_line, presence: true, length: { maximum: 255 }
  validate :address_limit_not_exceeded, on: :create

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :ordered, -> { order(is_default: :desc, created_at: :desc) }

  before_validation :normalize_fields
  after_save :ensure_single_default
  after_destroy :ensure_remaining_default

  def full_text
    "#{recipient_name} / #{phone} / #{address_line}"
  end

  private

  def normalize_fields
    self.recipient_name = recipient_name.to_s.strip
    self.phone = phone.to_s.strip
    self.address_line = address_line.to_s.strip
  end

  def address_limit_not_exceeded
    return if user_id.blank?
    return unless self.class.for_user(user_id).count >= MAX_ADDRESSES_PER_USER

    errors.add(:base, I18n.t("points_mall.errors.address_limit_reached", count: MAX_ADDRESSES_PER_USER))
  end

  def ensure_single_default
    return unless is_default?

    self.class.where(user_id: user_id).where.not(id: id).update_all(is_default: false)
  end

  def ensure_remaining_default
    first = self.class.for_user(user_id).order(created_at: :asc).first
    first&.update_columns(is_default: true) unless first.nil? || first.is_default?
  end
end
