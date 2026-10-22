class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user

  after_initialize do
    self.provider ||= :xai if new_record?
  end
end
