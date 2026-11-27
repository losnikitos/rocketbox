# frozen_string_literal: true

require "open3"

# Renders one Studio Post to MP4: Ferrum stills/overlays/CTA + ffmpeg simple fade.
class PostRenderJob < ApplicationJob
  queue_as :default

  HOLD = 2.0
  FADE = 0.5
  FPS = 30

  def perform(render)
    render.update!(status: :running, error: nil)
    Dir.mktmpdir("post-render") do |dir|
      file = assemble!(render, dir)
      render.file.attach(io: File.open(file), filename: render.filename, content_type: "video/mp4")
    end
    render.update!(status: :done)
  rescue => e
    render.update!(status: :failed, error: e.message)
    raise
  end

  private

    def assemble!(render, dir)
      post = render.post
      preset = post.preset
      scenes = post.scenes.select(&:renderable?)
      raise "no scenes to render" if scenes.empty?

      pngs = scenes.each_with_index.map do |scene, i|
        html = ApplicationController.render(
          template: "accounts/posts/canvas",
          layout: false,
          assigns: { post: post, preset: preset, scene: scene },
          locals: { data_url: true }
        )
        path = File.join(dir, format("scene-%02d.png", i))
        File.binwrite(path, Preset.screenshot(html, size: preset.size))
        path
      end

      case preset.transition_type
      when "simple_fade" then simple_fade!(pngs, File.join(dir, "out.mp4"), size: preset.size)
      else raise "unknown transition #{preset.transition_type}"
      end
    end

    # Hold each PNG, crossfade with ffmpeg xfade. ponytail: one transition type for now.
    def simple_fade!(pngs, out, size:)
      return still_to_mp4!(pngs.first, out, size:) if pngs.one?

      inputs = pngs.flat_map { [ "-loop", "1", "-t", (HOLD + FADE).to_s, "-i", it ] }
      w, h = size
      filter = pngs.each_index.map { |i| "[#{i}:v]scale=#{w}:#{h}:force_original_aspect_ratio=increase,crop=#{w}:#{h},setsar=1,fps=#{FPS},format=yuv420p[v#{i}]" }
      offset = HOLD
      chain = "[v0]"
      (1...pngs.size).each do |i|
        next_label = i == pngs.size - 1 ? "[vout]" : "[x#{i}]"
        filter << "#{chain}[v#{i}]xfade=transition=fade:duration=#{FADE}:offset=#{offset}#{next_label}"
        chain = "[x#{i}]"
        offset += HOLD
      end

      ffmpeg!(*inputs, "-filter_complex", filter.join(";"), "-map", "[vout]",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", out)
      out
    end

    def still_to_mp4!(png, out, size:)
      w, h = size
      ffmpeg!("-loop", "1", "-t", HOLD.to_s, "-i", png,
        "-vf", "scale=#{w}:#{h}:force_original_aspect_ratio=increase,crop=#{w}:#{h},setsar=1,fps=#{FPS},format=yuv420p",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", out)
      out
    end

    def ffmpeg!(*args)
      log, status = Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", *args)
      raise "ffmpeg failed: #{log.lines.last(3).join.strip.presence || status}" unless status.success?
    end
end
