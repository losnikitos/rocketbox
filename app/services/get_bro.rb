# frozen_string_literal: true

# Cloud stealth browser: https://getbro.ws/sdk_full.md (we call the HTTP API directly).
module GetBro
  Error = Class.new(StandardError)

  BASE_URL = "https://api.getbro.ws"
  POLL_INTERVAL = 2
  TIMEOUT = 5.minutes
  # Sessions run in the EU, where Google (incl. Maps) opens on a cookie consent wall. The first form is "Reject all";
  # submitting it redirects back to the requested page.
  DISMISS_GOOGLE_CONSENT_JS = <<~JS.squish
    (() => {
      const form = document.querySelector('form[action*="consent.google"]');
      if (!form) return "none";
      form.querySelector('button, input[type=submit]').click();
      return "dismissed";
    })()
  JS

  module_function

  def api_key
    Rails.application.credentials.dig(:get_bro, :api_key).presence || raise(Error, "credentials.get_bro.api_key is missing")
  end

  # Opens the page, screenshots it, then runs autopilot `extract`.
  # `schema` is loosely typed: { field => description }.
  # => { extracted: Hash | Array, screenshot_url: String }
  def extract(url, data_instruction:, schema:)
    deadline = TIMEOUT.from_now
    session_id = create_session(deadline)
    run(session_id, deadline, "open_url", url: url)
    if run(session_id, deadline, "run_js", js_code: DISMISS_GOOGLE_CONSENT_JS, out_type: "str").dig("data", "result") == "dismissed"
      run(session_id, deadline, "sleep", wait_time: 5)
    end
    screenshot_url = begin
      run(session_id, deadline, "get_screenshot", mode: "viewport").dig("data", "image_url")
    rescue Error
      nil
    end
    step = run(session_id, deadline, "extract",
      data_instruction: data_instruction, json_schema: schema, model_size: "small", feed_urls: true, viewport_max: 2)

    { extracted: step.dig("data", "extracted_json"), screenshot_url: screenshot_url }
  ensure
    http.delete("/v1/sessions/#{session_id}") if session_id
  end

  def create_session(deadline)
    session_id = request!(:post, "/v1/sessions", {}).fetch("session_id")
    poll(deadline) do
      status = request!(:get, "/v1/sessions/#{session_id}")["status"]
      raise Error, "GetBro session #{status}" if status.in?(%w[failed cancelled terminated stopped])

      session_id if status == "idle"
    end
  end

  # Runs one command and returns its step ({ "success", "data", "error_message", ... }).
  def run(session_id, deadline, command, **params)
    command_id = request!(:post, "/v1/sessions/#{session_id}/execute", { commands: [ { command: command, params: params } ] })["command_id"]
    result = poll(deadline) do
      data = request!(:get, "/v1/sessions/#{session_id}/commands/#{command_id}")
      raise Error, "#{command} failed: #{data["error_message"] || data["error_name"]}" if data["status"] == "failed"

      data if data["status"] == "done"
    end

    step = result.dig("response", "commands")&.find { |s| s["command"] == command }
    raise Error, "#{command} failed: #{step&.dig("error_message") || step&.dig("error_name") || "no result"}" unless step&.dig("success")

    step
  end

  def poll(deadline)
    loop do
      value = yield
      return value if value
      raise Error, "GetBro timed out" if Time.current > deadline

      sleep POLL_INTERVAL
    end
  end

  def request!(method, path, body = nil)
    response = http.public_send(method, path, body)
    raise Error, "GetBro HTTP #{response.status}: #{response.body}" unless response.success?

    response.body
  end

  def http
    Faraday.new(url: BASE_URL, headers: { "Authorization" => "Bearer #{api_key}" }, request: { timeout: 180 }) do |f|
      f.request :json
      f.response :json
    end
  end
end
