# frozen_string_literal: true

class SignupsController < ApplicationController
  include AuthFlow

  layout "auth"
  skip_before_action :authenticate

  before_action :require_draft_through_business!, only: %i[email email_submit email_code email_code_submit], unless: :admin_preview?
  before_action :require_draft_email!, only: %i[email_code email_code_submit], unless: :admin_preview?
  before_action :require_signed_in_for_whatsapp!, only: %i[whatsapp whatsapp_skip]

  def show
    redirect_to next_step_path
  end

  def name
    @name = draft[:name]
  end

  def name_submit
    value = params[:name].to_s.strip
    if value.blank?
      @name = value
      flash.now[:alert] = "Enter your name"
      return render :name, status: :unprocessable_entity
    end

    update_draft(name: value)
    redirect_to sign_up_business_path
  end

  def business
    @business_name = draft[:business_name]
  end

  def business_submit
    value = params[:business_name].to_s.strip
    if value.blank?
      @business_name = value
      flash.now[:alert] = "Enter your business name"
      return render :business, status: :unprocessable_entity
    end

    update_draft(business_name: value)
    redirect_to sign_up_email_path
  end

  def email
    @email = draft[:email].presence || params[:email_hint]
  end

  def email_submit
    email = LoginChallenge.normalize(params[:email])
    if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP
      @email = params[:email]
      flash.now[:alert] = "Enter a valid email"
      return render :email, status: :unprocessable_entity
    end

    update_draft(email: email)
    issue_email_otp!(email)
    redirect_to sign_up_email_code_path
  end

  def email_code
    @email = draft[:email]
    @otp_code = otp_preview_code
  end

  def email_code_submit
    if Current.user
      redirect_to sign_up_whatsapp_path
      return
    end

    email = draft[:email]
    unless LoginChallenge.verify_code!(email, params[:otp])
      @email = email
      @otp_code = otp_preview_code
      flash.now[:alert] = "That code is invalid or expired"
      return render :email_code, status: :unprocessable_entity
    end

    if (user = User.find_by(email: email))
      user.update!(verified: true) unless user.verified?
      start_session!(user)
      clear_draft!
      redirect_to app_path, notice: "Signed in successfully"
      return
    end

    user = User.create!(
      email: email,
      name: draft[:name],
      business_name: draft[:business_name],
      verified: true
    )
    start_session!(user)
    redirect_to sign_up_whatsapp_path
  end

  def whatsapp
    return whatsapp_skip if Current.account.whatsapp_phone.present? && !admin_preview?

    @whatsapp_url = "https://wa.me/#{WhatsappCloud.display_phone}?text=START_#{Current.account.whatsapp_connect_code!}"
  end

  def whatsapp_skip
    clear_draft!
    redirect_to app_path, notice: "Welcome! You have signed up successfully"
  end

  private

    # Admins open any screen from /app/onboarding; only the CTAs (POSTs) run the real flow.
    def admin_preview?
      request.get? && Current.user&.admin?
    end

    def draft
      session[:signup] ||= {}
      session[:signup].with_indifferent_access
    end

    def update_draft(**attrs)
      session[:signup] = draft.merge(attrs.stringify_keys)
    end

    def clear_draft!
      session.delete(:signup)
      clear_otp_preview!
    end

    def next_step_path
      return sign_up_whatsapp_path if Current.user
      return sign_up_email_code_path if draft[:email].present?
      return sign_up_email_path if draft[:business_name].present?
      return sign_up_business_path if draft[:name].present?

      sign_up_name_path
    end

    def require_draft_through_business!
      return if draft[:name].present? && draft[:business_name].present?

      redirect_to next_step_path
    end

    def require_draft_email!
      return if draft[:email].present?

      redirect_to sign_up_email_path
    end

    def require_signed_in_for_whatsapp!
      return if Current.user

      redirect_to sign_up_path
    end
end
