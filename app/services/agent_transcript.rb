# frozen_string_literal: true

# Rebuilds a user's chat from the records that already are the log: incoming messages,
# settled workflow runs, and outgoing texts. The chat is a render, wiped on each reply.
# ponytail: a tool result is read live, so a later move of the same media changes an old
# result, and a tool the model calls itself is gone on the next wipe. Upgrade = stop wiping
# and append. No cap on length yet.
class AgentTranscript
  # image (WhatsApp) and photo (Telegram) are the same thing to the model.
  PHOTO = { "image" => "photo", "photo" => "photo" }.freeze

  def self.call(chat, user) = new(chat, user).call

  # The messages a reply would rebuild, without touching the user's chat.
  def self.preview(user)
    sink = Preview.new
    call(sink, user)
    sink.messages
  end

  # Collects add_message calls in memory. Not a Chat, so a preview writes nothing.
  class Preview
    attr_reader :messages

    def initialize
      @messages = []
    end

    def add_message(**message)
      @messages << message
    end
  end

  # What a workflow run took and made. A Sort's result is the source, so WorkflowRun#inputs/#outputs
  # (a set difference) is empty; this lists the step runs instead. The model receives this as JSON.
  def self.trace(run)
    {
      status: run.state,
      error: run.error,
      inputs: run.step_runs.flat_map(&:sources).uniq.map { item_ref(it) },
      outputs: run.step_runs.filter_map(&:result).uniq.map { item_ref(it) }
    }
  end

  def self.item_ref(item)
    id_key = { media: :media_id, prompt: :prompt_id, review: :review_id }.fetch(item.item_kind, :id)
    { id_key => item.id, folder: item.folder.path }
  end

  def initialize(chat, user)
    @chat = chat
    @user = user
  end

  def call
    events.each { render(it) }
  end

  private

    def events
      rows = @user.incoming_messages.to_a.map { [ it, 0 ] }
      rows += runs.map { [ it, 1 ] }
      rows += sent.map { [ it, 2 ] }
      rows.sort_by { |record, rank| [ record.created_at, rank, record.id ] }.map(&:first)
    end

    # Skip runs that still have a step running or waiting. The page shows those; the model does not.
    def runs
      busy = TransformationRun.where(status: %w[running waiting]).select(:workflow_run_id)
      WorkflowRun.played_by(@user).where.not(id: busy)
        .includes(:workflow, step_runs: { inputs: { item: :folder }, result: :folder })
    end

    def sent
      @user.outgoing_messages.where(error: nil).where.not(kind: "reaction").where.not(body: [ nil, "" ])
    end

    def render(record)
      case record
      when IncomingMessage then render_incoming(record)
      when WorkflowRun then render_run(record)
      when OutgoingMessage then @chat.add_message(role: :assistant, content: record.body)
      end
    end

    # Media stays in the library for workflows. The model only hears that it arrived.
    def render_incoming(message)
      @chat.add_message(role: :user, content: incoming_content(message))
    end

    def incoming_content(message)
      text = message.body.presence
      kind = message.kind.to_s
      return text if text && (kind.blank? || kind.in?(%w[text interactive]))

      note = "Sent a #{PHOTO.fetch(kind, kind.presence || "message")}"
      text ? "#{note}: #{text}" : note
    end

    # Name is the workflow slug underscored, so a later tool class can use the same name.
    def render_run(run)
      id = "run_#{run.id}"
      media_ids = run.picks.values.flatten.map(&:to_i).uniq
      @chat.add_message(
        role: :assistant,
        content: "",
        tool_calls: { id => RubyLLM::ToolCall.new(id:, name: run.workflow.slug.underscore, arguments: { media_ids: }) }
      )
      @chat.add_message(role: :tool, content: result_json(run), tool_call_id: id)
    end

    def result_json(run) = self.class.trace(run).to_json
end
