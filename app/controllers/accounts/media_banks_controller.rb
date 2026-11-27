# frozen_string_literal: true

module Accounts
  # Shared reference photos (Folder.bank) for Studio — browse, filter, upload, tag, delete.
  # Posts pick items by id via the source dropdown.
  class MediaBanksController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_media, only: %i[show update destroy]

    # Tags that classify the shot, not the business (shop slug).
    CATEGORY_TAGS = %w[barbershop storefront exterior interior logo].freeze

    def index
      @tag = Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
      media = LibraryMedia.bank.with_attached_file.includes(:tags).order(created_at: :desc)
      media = media.tagged_all([ @tag.id ]) if @tag
      @items = media.to_a
      @groups = @items.group_by { bank_business_label(it) }.sort_by(&:first)
      @tag_counts = Tag.joins(:library_media).merge(LibraryMedia.bank).group(:id).count
      @tags = Tag.ordered.select { @tag_counts[it.id] }
    end

    def show
      siblings = LibraryMedia.bank.with_attached_file.includes(:tags).order(created_at: :desc).to_a
      i = siblings.index(@media)
      @prev = siblings[i - 1] if i&.positive?
      @next = siblings[i + 1] if i && i < siblings.size - 1
    end

    def create
      files = Array(params[:files]).compact_blank
      if files.empty?
        redirect_to media_banks_path(tag_id: params[:tag_id].presence), alert: "Choose at least one image." and return
      end

      created = files.map do |file|
        LibraryMedia.create!(kind: "photo", folder: Folder.bank).tap { it.file.attach(file) }
      end
      path = created.one? ? media_bank_path(created.first) : media_banks_path(tag_id: params[:tag_id].presence)
      redirect_to path, notice: "Uploaded #{created.size} #{'image'.pluralize(created.size)}."
    end

    def update
      attrs = params.expect(library_media: [ tag_ids: [] ])
      if @media.update(attrs)
        head :no_content
      else
        redirect_to media_bank_path(@media), alert: @media.errors.full_messages.to_sentence
      end
    end

    def destroy
      @media.destroy!
      redirect_to media_banks_path, notice: "Deleted."
    end

    private

      def set_media
        @media = LibraryMedia.bank.with_attached_file.includes(:tags).find(params[:id])
      end

      def bank_business_label(media)
        name = media.tags.map(&:name).find { CATEGORY_TAGS.exclude?(it) }
        name&.tr("-", " ")&.sub(/\A\d+\s*/, "")&.titleize || "Untagged"
      end
      helper_method :bank_business_label
  end
end
