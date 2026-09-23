class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ransack 4+ (Active Admin) — allowlist all columns/associations for admin search.
  def self.ransackable_attributes(_auth_object = nil)
    column_names
  end

  def self.ransackable_associations(_auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
