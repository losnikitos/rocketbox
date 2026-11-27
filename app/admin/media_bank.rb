# frozen_string_literal: true

# Dropbox-like browse/upload for the admin media bank (LibraryMedia in Folder.bank).
ActiveAdmin.register_page "Media Bank" do
  menu priority: 2, label: "Media bank"

  content title: "Media bank" do
    tag_id = params[:tag_id].presence
    media = LibraryMedia.bank.with_attached_file.includes(:tags).order(created_at: :desc)
    media = media.tagged_all([ tag_id.to_i ]) if tag_id

    panel "Upload" do
      form action: admin_media_bank_upload_path, method: :post, enctype: "multipart/form-data" do
        input type: :hidden, name: :authenticity_token, value: form_authenticity_token
        para do
          label "Images"
          input type: :file, name: "files[]", accept: "image/*", multiple: true, required: true
        end
        para "Tags"
        Tag.ordered.each do |tag|
          label style: "display:inline-block;margin:0 12px 8px 0" do
            input type: :checkbox, name: "tag_ids[]", value: tag.id
            text_node " ##{tag.name}"
          end
        end
        para { input type: :submit, value: "Upload" }
      end
    end

    panel "Tags" do
      span { link_to "All (#{LibraryMedia.bank.count})", admin_media_bank_path }
      text_node " "
      Tag.ordered.each do |tag|
        count = tag.library_media.merge(LibraryMedia.bank).count
        next if count.zero?

        span do
          link_to "##{tag.name} (#{count})", admin_media_bank_path(tag_id: tag.id),
            style: ("font-weight:600" if tag_id.to_i == tag.id)
        end
        text_node " "
      end
    end

    panel "Library" do
      if media.any?
        div style: "display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:12px" do
          media.each do |item|
            div style: "border:1px solid #e5e5e5;border-radius:8px;overflow:hidden;background:#fff" do
              if item.file.attached? && item.file.variable?
                a href: rails_blob_path(item.file, disposition: "inline"), target: "_blank", rel: "noopener" do
                  img src: url_for(item.file.variant(resize_to_limit: [ 280, 280 ])),
                    alt: item.tags.map(&:name).join(" "),
                    style: "display:block;width:100%;aspect-ratio:1;object-fit:cover"
                end
              end
              div style: "padding:8px;font-size:12px;line-height:1.3" do
                para item.tags.ordered.map { |t| "##{t.name}" }.join(" ")
                form action: admin_media_bank_destroy_path(id: item.id), method: :post do
                  input type: :hidden, name: :authenticity_token, value: form_authenticity_token
                  input type: :hidden, name: :_method, value: :delete
                  input type: :submit, value: "Delete",
                    onclick: "return confirm('Delete this image?')",
                    style: "color:#b91c1c;background:none;border:0;padding:0;cursor:pointer"
                end
              end
            end
          end
        end
      else
        para "No images yet. Upload above or run bin/rails media_bank:seed."
      end
    end
  end

  page_action :upload, method: :post do
    files = Array(params[:files]).compact_blank
    tag_ids = Array(params[:tag_ids]).compact_blank
    if files.empty?
      redirect_to admin_media_bank_path, alert: "Choose at least one image." and return
    end

    files.each do |file|
      media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, tag_ids:)
      media.file.attach(file)
    end
    redirect_to admin_media_bank_path, notice: "Uploaded #{files.size} #{'image'.pluralize(files.size)}."
  end

  page_action :destroy, method: :delete do
    LibraryMedia.bank.find(params[:id]).destroy!
    redirect_to admin_media_bank_path, notice: "Deleted."
  end
end
