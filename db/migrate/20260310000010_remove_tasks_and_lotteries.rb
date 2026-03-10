# frozen_string_literal: true

class RemoveTasksAndLotteries < ActiveRecord::Migration[7.0]
  def up
    # Keep legacy task/lottery tables in place for safe deploy.
    # Discourse blocks destructive table drops in regular migrations.
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
