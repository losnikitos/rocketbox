# frozen_string_literal: true

class SessionsController < ApplicationController
  include AuthFlow

  layout "auth", only: %i[new create otp otp_create]
  skip_before_action :authenticate, only: %i[ new create otp otp_create magic dev ]

  before_action :set_session, only: :destroy

  def index
    @sessions = Current.user.sessions.order(created_at: :desc)
  end

  def new
    @email = params[:email_hint]
  end

  def create
    email = LoginChallenge.normalize(params[:email])
    if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP
      @email = params[:email]
      flash.now[:alert] = "Enter a valid email"
      return render :new, status: :unprocessable_entity
    end

    issue_email_otp!(email)
    redirect_to sign_in_otp_path(email:)
  end

  def otp
    @email = LoginChallenge.normalize(params[:email])
    if @email.blank?
      redirect_to sign_in_path, alert: "Enter your email first"
      return
    end

    @otp_code = otp_preview_code
  end

  def otp_create
    email = LoginChallenge.normalize(params[:email])
    if LoginChallenge.verify_code!(email, params[:otp])
      sign_in_from_email!(email)
    else
      @email = email
      @otp_code = otp_preview_code
      flash.now[:alert] = "That code is invalid or expired"
      render :otp, status: :unprocessable_entity
    end
  end

  def magic
    email = LoginChallenge.verify_token!(params[:sid])
    sign_in_from_email!(email)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to sign_in_path, alert: "That login link is invalid or expired"
  end

  def dev
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?

    user = User.find_by!(email: "losnikitos@gmail.com")
    start_session!(user)
    redirect_to app_path, notice: "Signed in successfully"
  end

  def destroy
    @session.destroy; redirect_to(sessions_path, notice: "That session has been logged out")
  end

  def destroy_current
    Current.session&.destroy
    cookies.delete(:session_token)
    redirect_to sign_in_path, notice: "Signed out"
  end

  private
    def set_session
      @session = Current.user.sessions.find(params[:id])
    end

    def sign_in_from_email!(email)
      user = User.find_or_create_from_login!(email)
      start_session!(user)
      clear_otp_preview!
      redirect_to app_path, notice: "Signed in successfully"
    end
end
