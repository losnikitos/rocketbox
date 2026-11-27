# frozen_string_literal: true

class ReseedBarbershopGuideRules < ActiveRecord::Migration[8.1]
  def up
    guide = Guide.find_or_initialize_by(slug: "barbershop")
    guide.update!(
      title: "Barbershop",
      lede: "The franchisee handbook — how the shop should look, run, book, market, and keep the books.",
      published: true
    )
    guide.chapters.destroy_all

    seed = [
      {
        slug: "visual-appeal",
        title: "Visual appeal",
        lede: "What walk-ins see before they sit down — facade, uniform, and light.",
        position: 1,
        rules: [
          {
            number: 10,
            title: "Keep the facade clear",
            position: 1,
            body: <<~MD
              A tidy shop reads as professional before anyone sits down. One sign on the facade — no sticker collage.

              :::compare
              do: /guides/barbershop/clean.jpg
              dont: /guides/barbershop/cluttered.jpg
              do_label: Clear facade
              dont_label: Sticker clutter
              :::
            MD
          },
          {
            number: 11,
            title: "Look the part",
            position: 2,
            body: <<~MD
              The uniform is part of the brand. Black shirt, white apron on the floor — no loud prints or weekend tees while working.

              :::compare
              do: /guides/barbershop/uniform.jpg
              dont: /guides/barbershop/casual.jpg
              do_label: Neat uniform
              dont_label: Casual clothes
              :::
            MD
          },
          {
            number: 12,
            title: "Use warm light",
            position: 3,
            body: <<~MD
              Warm light flatters skin and wood; cool light makes everything clinical. Prefer warm bulbs in the chair area.

              :::compare
              do: /guides/barbershop/warm.jpg
              dont: /guides/barbershop/cool.jpg
              do_label: Warm light
              dont_label: Cool light
              :::
            MD
          }
        ]
      },
      {
        slug: "marketing",
        title: "Marketing",
        lede: "Show the work. Keep the feed alive without leaving the chair.",
        position: 2,
        rules: [
          {
            number: 20,
            title: "Photograph every finished cut",
            position: 1,
            body: <<~MD
              Before the client leaves, take one clear photo of the finished cut. Same angle each time — head-and-shoulders, good light, no clutter behind.

              Send it from the shop phone the same day. Yesterday’s cuts belong in yesterday’s posts.
            MD
          },
          {
            number: 21,
            title: "Post before you clock out",
            position: 2,
            body: <<~MD
              Don’t batch a week of content on Sunday night. Post (or queue) while the cut is still fresh — same-day posts book the next chair.
            MD
          }
        ]
      },
      {
        slug: "booking",
        title: "Booking",
        lede: "How clients get in the chair — and how you avoid no-shows.",
        position: 3,
        rules: [
          {
            number: 30,
            title: "One booking system only",
            position: 1,
            body: <<~MD
              Use the shop’s booking tool for every appointment. No parallel WhatsApp diaries, no paper diary beside the till.

              Walk-ins still welcome — mark them in the same system so the next barber can see the load.
            MD
          },
          {
            number: 31,
            title: "Confirm the day before",
            position: 2,
            body: <<~MD
              Send an automatic reminder the day before. If they cancel, free the slot the same hour — don’t sit on empty chairs.
            MD
          }
        ]
      },
      {
        slug: "equipment",
        title: "Equipment",
        lede: "Tools that stay sharp keep the line moving.",
        position: 4,
        rules: [
          {
            number: 40,
            title: "Clean clippers between clients",
            position: 1,
            body: <<~MD
              Brush, wipe, and oil as the manufacturer says. A sticky blade slows the cut and looks careless when a client sees it.
            MD
          },
          {
            number: 41,
            title: "Replace blades on schedule",
            position: 2,
            body: <<~MD
              Don’t wait for a nick. Keep a dated log on the station cupboard and swap blades when due.
            MD
          }
        ]
      },
      {
        slug: "accounting",
        title: "Accounting",
        lede: "Cash, card, tips — recorded the same way every night.",
        position: 5,
        rules: [
          {
            number: 50,
            title: "Close the till every night",
            position: 1,
            body: <<~MD
              Count cash, match card totals, and file the Z-report before locking up. Gaps overnight become mysteries by Monday.
            MD
          },
          {
            number: 51,
            title: "Tips go through the till",
            position: 2,
            body: <<~MD
              Record tips in the same system as services. Side cash breaks the books and the tip share.
            MD
          }
        ]
      }
    ]

    seed.each do |chapter_attrs|
      rules = chapter_attrs.delete(:rules)
      chapter = guide.chapters.create!(chapter_attrs)
      rules.each { |rule| chapter.rules.create!(rule.merge(guide:)) }
    end
  end

  def down
    Guide.find_by(slug: "barbershop")&.chapters&.destroy_all
  end
end
