# frozen_string_literal: true

class CreatePointsMallTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_tasks do |t|
      t.string :name, null: false
      t.text :description
      t.integer :points_reward, null: false
      t.string :task_type, null: false
      t.integer :target_count, default: 1
      t.boolean :enabled, default: true
      t.boolean :repeatable, default: true
      t.string :repeat_type, default: 'daily'
      t.timestamps
    end

    add_index :points_mall_tasks, :enabled
    add_index :points_mall_tasks, :task_type
  end
end
