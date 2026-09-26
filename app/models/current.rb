class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :account
  attribute :user_agent, :ip_address

  delegate :user, to: :session, allow_nil: true

  # Company being viewed/edited. Admins may override via session[:account_user_id].
  def account
    super || user
  end
end
