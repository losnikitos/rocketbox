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

    # A run is played as this user; its step runs' results are their media or prompts.
    # Skip drafts and runs that still have a step running or waiting.
    def runs
      owned = TransformationRun.where.not(workflow_run_id: nil).where(status: %w[complete failed rejected]).where(
        "(result_type = 'LibraryMedia' AND result_id IN (:media)) OR (result_type = 'Prompt' AND result_id IN (:prompts))",
        media: @user.library_media.select(:id),
        prompts: @user.prompts.select(:id)
      ).select(:workflow_run_id)
      busy = TransformationRun.where(status: %w[running waiting]).select(:workflow_run_id)

      WorkflowRun.where(id: owned, status: "started").where.not(id: busy)
        .includes(:workflow, step_runs: { inputs: :item, result: :folder })
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

    def render_incoming(message)
      @chat.add_message(
        role: :user,
        content: message.body.presence || "Sent a #{PHOTO.fetch(message.kind.to_s, message.kind.presence || "message")}",
        attachments: message.attachments.attached? ? message.attachments.blobs : nil
      )
    end

    # Name is the workflow slug underscored, so a later tool class can use the same name.
    # A Sort's result is the source, so WorkflowRun#inputs/#outputs (a set difference) is empty;
    # list what the run took and made instead.
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

    def result_json(run)
      {
        status: run.state,
        error: run.error,
        inputs: run.step_runs.flat_map(&:sources).uniq.map { item_ref(it) },
        outputs: run.step_runs.filter_map(&:result).uniq.map { item_ref(it) }
      }.to_json
    end

    def item_ref(item)
      id_key = { media: :media_id, prompt: :prompt_id, review: :review_id }.fetch(item.item_kind, :id)
      { id_key => item.id, folder: item.folder.path }
    end
end
