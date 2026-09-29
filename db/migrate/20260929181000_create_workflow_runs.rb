class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  WORKFLOWS = {
    "Transition A->B" => "Transition",
    "Cinematic shop reel" => "CinematicShopReel",
    "Before → after energy" => "BeforeAfterEnergy",
    "Quiet craftsmanship" => "QuietCraftsmanship",
    "Bank holiday story" => "BankHolidayStory"
  }.freeze

  def up
    add_column :recipes, :workflow, :string, null: false, default: "CinematicShopReel"
    WORKFLOWS.each { |name, workflow| execute "UPDATE recipes SET workflow = #{quote(workflow)} WHERE name = #{quote(name)}" }
    change_column_default :recipes, :workflow, from: "CinematicShopReel", to: nil
    add_index :recipes, :workflow, unique: true
    remove_column :recipes, :prompt
    remove_column :recipes, :media_type

    create_table :workflow_runs do |t|
      t.references :smm_post, null: false, foreign_key: true
      t.string :workflow, null: false
      t.string :status, null: false, default: "running"
      t.text :error
      t.timestamps
    end

    create_table :workflow_steps do |t|
      t.references :workflow_run, null: false, foreign_key: true
      t.string :key, null: false
      t.string :status, null: false, default: "pending"
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
      t.index %i[workflow_run_id key], unique: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
