class Chat < ApplicationRecord
  acts_as_chat

  after_initialize do
    self.provider ||= :xai if new_record?
  end
end
