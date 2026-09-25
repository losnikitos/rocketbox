class MonitorController < ApplicationController
  layout "monitor"
  before_action :authenticate_admin!

  def show
  end
end
