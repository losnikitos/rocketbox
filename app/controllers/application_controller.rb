class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :resume_session
  before_action :set_footer_documents
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

    # Public HTML pages that do not require a session (same shell as the rest of the app).
    def allow_public_access?
      return true if request.path == "/" && (request.get? || request.head?)
      return true if controller_name == "documents" && action_name == "show" && (request.get? || request.head?)

      false
    end

    def set_current_request_details
      Current.user_agent = request.user_agent
      Current.ip_address = request.ip
    end

    def set_footer_documents
      @footer_documents = Document.published.order(:title)
    end
end
