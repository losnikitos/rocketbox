# frozen_string_literal: true

namespace :media_bank do
  desc "Seed Folder.bank from a directory of images (default: tmp/barbershop-storefronts)"
  task seed: :environment do
    dir = ENV.fetch("DIR", Rails.root.join("tmp/barbershop-storefronts"))
    abort "Missing directory: #{dir}" unless File.directory?(dir)

    Folder.roots.find_or_create_by!(slug: "bank") { it.assign_attributes(name: "Bank", color: "slate", kind: "media") }
    count_before = LibraryMedia.bank.count
    LibraryMedia.seed_bank_from!(dir)
    puts "Bank media: #{count_before} → #{LibraryMedia.bank.count} (from #{dir})"
  end

  desc "Export bank media + S3 blob metadata to JSON (FILE=tmp/media_bank_export.json)"
  task export: :environment do
    file = Pathname(ENV.fetch("FILE", Rails.root.join("tmp/media_bank_export.json")))
    payload = LibraryMedia.bank.with_attached_file.includes(:tags).find_each.filter_map do |media|
      next unless media.file.attached?

      blob = media.file.blob
      {
        source_url: media.source_url,
        tag_names: media.tags.map(&:name),
        blob: blob.as_json(only: %w[key filename content_type byte_size checksum service_name metadata])
      }
    end
    file.write(JSON.pretty_generate(payload))
    puts "Wrote #{payload.size} items → #{file}"
  end

  # Reuses existing S3 objects (same festivo/rocketbox keys). Idempotent on source_url.
  desc "Import bank media from export JSON (FILE=tmp/media_bank_export.json)"
  task import: :environment do
    file = Pathname(ENV.fetch("FILE", Rails.root.join("tmp/media_bank_export.json")))
    abort "Missing #{file}" unless file.file?

    Folder.roots.find_or_create_by!(slug: "bank") { it.assign_attributes(name: "Bank", color: "slate", kind: "media") }
    payload = JSON.parse(file.read)
    created = 0
    payload.each do |row|
      next if LibraryMedia.exists?(user_id: nil, source_url: row["source_url"])

      blob_attrs = row.fetch("blob")
      blob = ActiveStorage::Blob.find_by(key: blob_attrs["key"]) || ActiveStorage::Blob.create!(
        key: blob_attrs["key"],
        filename: blob_attrs["filename"],
        content_type: blob_attrs["content_type"],
        byte_size: blob_attrs["byte_size"],
        checksum: blob_attrs["checksum"],
        service_name: blob_attrs["service_name"].presence || "amazon",
        metadata: blob_attrs["metadata"] || {}
      )
      tags = Array(row["tag_names"]).map { Tag.find_or_create_by!(name: it) }
      media = LibraryMedia.create!(kind: "photo", folder: Folder.bank, source_url: row["source_url"], tags:)
      media.file.attach(blob)
      created += 1
    end
    puts "Imported #{created} new bank media (#{LibraryMedia.bank.count} total)"
  end
end
