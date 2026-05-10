class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :resume_session
  before_action :authenticate

  private
    def resume_session
      if session_record = Session.find_by_id(cookies.signed[:session_token])
        Current.session = session_record
      end
    end

    def authenticate
      return if allow_public_access?

      redirect_to sign_in_path unless Current.session
    end

    # Root route (`/`) is the public landing page — same in dev and production.
    def allow_public_access?
      request.path == "/" && (request.get? || request.head?)
    end

    def set_current_request_details
      Current.user_agent = request.user_agent
      Current.ip_address = request.ip
    end
end
