class SessionsController < ApplicationController
  skip_before_action :authenticate, only: %i[ new create otp otp_create magic password password_create dev ]

  before_action :set_session, only: :destroy

  def index
    @sessions = Current.user.sessions.order(created_at: :desc)
  end

  def new
  end

  def create
    email = LoginChallenge.normalize(params[:email])
    if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP
      redirect_to sign_in_path, alert: "Enter a valid email"
      return
    end

    challenge = LoginChallenge.issue!(email)
    if challenge == :throttled
      redirect_to sign_in_otp_path(email:), notice: "Check your email for a login code"
      return
    end

    UserMailer.with(
      email: challenge[:email],
      otp_code: challenge[:code],
      magic_token: challenge[:token]
    ).login_otp.deliver_later

    redirect_to sign_in_otp_path(email: challenge[:email]), notice: "Check your email for a login code"
  end

  def otp
    @email = LoginChallenge.normalize(params[:email])
    redirect_to sign_in_path, alert: "Enter your email first" if @email.blank?
  end

  def otp_create
    email = LoginChallenge.normalize(params[:email])
    if LoginChallenge.verify_code!(email, params[:otp])
      sign_in_from_email!(email)
    else
      redirect_to sign_in_otp_path(email:), alert: "That code is invalid or expired"
    end
  end

  def magic
    email = LoginChallenge.verify_token!(params[:sid])
    sign_in_from_email!(email)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to sign_in_path, alert: "That login link is invalid or expired"
  end

  def password
  end

  def password_create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      start_session!(user)
      redirect_to root_path, notice: "Signed in successfully"
    else
      redirect_to sign_in_password_path(email_hint: params[:email]), alert: "That email or password is incorrect"
    end
  end

  def dev
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?

    user = User.find_by!(email: "losnikitos@gmail.com")
    start_session!(user)
    redirect_to root_path, notice: "Signed in successfully"
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
      redirect_to root_path, notice: "Signed in successfully"
    end

    def start_session!(user)
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
    end
end
