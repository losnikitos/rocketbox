class MovePromptsToRecipes < ActiveRecord::Migration[8.1]
  PROMPTS = {
    "Transition" => "transition_video",
    "CinematicShopReel" => "cinematic_shop_reel_video",
    "BeforeAfterEnergy" => "before_after_energy_video",
    "QuietCraftsmanship" => "quiet_craftsmanship_video",
    "BankHolidayStory" => "bank_holiday_story_film"
  }.freeze
  RENAMES = PROMPTS.keys.index_with("ImagesToVideo").merge("BankHolidayStory" => "TwoPhotoStory").freeze
  BANK_HOLIDAY_TEXTS = { "text_1" => "This bank holiday we work as usual", "text_2" => "Tap link below to book" }.freeze

  def up
    add_column :recipes, :prompt, :text
    add_column :recipes, :texts, :json, null: false, default: {}

    PROMPTS.each do |workflow, key|
      execute "UPDATE recipes SET prompt = (SELECT body FROM prompts WHERE key = #{quote(key)}) WHERE workflow = #{quote(workflow)}"
    end
    execute "UPDATE recipes SET prompt = '' WHERE prompt IS NULL"
    change_column_null :recipes, :prompt, false
    execute "UPDATE recipes SET texts = #{quote(BANK_HOLIDAY_TEXTS.to_json)} WHERE workflow = 'BankHolidayStory'"

    remove_index :recipes, :workflow
    RENAMES.each do |from, to|
      %w[recipes workflow_runs].each { execute "UPDATE #{it} SET workflow = #{quote(to)} WHERE workflow = #{quote(from)}" }
    end

    execute "DELETE FROM prompts WHERE key IN (#{PROMPTS.values.map { quote(it) }.join(", ")})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
