ActiveAdmin.register User do
  permit_params :email, :name, :business_name, :role, :verified, :instagram_user_id, :instagram_access_token,
                :telegram_user_id, :whatsapp_phone

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :business_name
    column :role
    column :verified
    column :created_at
    actions
  end

  filter :email
  filter :role, as: :select, collection: User::ROLES
  filter :verified
  filter :created_at

  show do
    default_main_content

    # ponytail: last 100 each way; paginate if a chat outgrows that.
    messages = (resource.incoming_messages.with_attached_attachments.order(created_at: :desc).limit(100) +
                resource.outgoing_messages.order(created_at: :desc).limit(100)).sort_by(&:created_at)
    panel "Messages" do
      table_for messages do
        column(:time) { |m| link_to l(m.created_at, format: :short), [ :admin, m ] }
        column(:direction) { |m| m.is_a?(IncomingMessage) ? "← in" : "→ out" }
        column :channel
        column :kind
        column :body
        column(:media) { |m| admin_media_thumbs(m.attachments) if m.is_a?(IncomingMessage) }
        column(:error) { |m| m.try(:error) }
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :name
      f.input :business_name
      f.input :role, as: :select, collection: User::ROLES
      f.input :verified
      f.input :instagram_user_id
      f.input :instagram_access_token
      f.input :telegram_user_id
      f.input :whatsapp_phone
    end
    f.actions
  end
end
