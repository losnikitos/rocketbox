# Isolate Active Storage objects under rocketbox/ in the shared festivo S3 bucket.
# (Dedicated bucket needs CreateBucket; this IAM user doesn't have it.)
Rails.application.config.to_prepare do
  ActiveStorage::Blob.class_eval do
    def self.generate_unique_secure_token(length: MINIMUM_TOKEN_LENGTH)
      "rocketbox/#{SecureRandom.base36(length)}"
    end

    # Ransack 4+ (Active Admin) — same allowlist pattern as ApplicationRecord.
    def self.ransackable_attributes(_auth_object = nil) = column_names
    def self.ransackable_associations(_auth_object = nil) = reflect_on_all_associations.map { |a| a.name.to_s }
  end

  ActiveStorage::Attachment.class_eval do
    def self.ransackable_attributes(_auth_object = nil) = column_names
    def self.ransackable_associations(_auth_object = nil) = reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
