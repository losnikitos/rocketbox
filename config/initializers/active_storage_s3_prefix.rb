# Isolate Active Storage objects under rocketbox/ in the shared festivo S3 bucket.
# (Dedicated bucket needs CreateBucket; this IAM user doesn't have it.)
Rails.application.config.to_prepare do
  ActiveStorage::Blob.class_eval do
    def self.generate_unique_secure_token(length: MINIMUM_TOKEN_LENGTH)
      "rocketbox/#{SecureRandom.base36(length)}"
    end
  end
end
