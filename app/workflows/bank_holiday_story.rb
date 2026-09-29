# frozen_string_literal: true

class BankHolidayStory < Workflow
  FILM = "Candid 35mm colour-negative photograph, natural available light, slightly underexposed by half a stop. Soft low-contrast exposure with gentle highlight roll-off and lifted shadow detail. Subtle green-cyan colour cast in the shadows and neutral areas, slightly warm natural skin tones, muted reds and blues, restrained saturation. Fine organic film grain throughout with slightly coarser grain in darker areas. Mild lens softness, very subtle halation and bloom around highlights, reduced digital micro-contrast, imperfect edge sharpness. Feels scanned from an analogue print rather than captured digitally. Casual documentary framing, spontaneous snapshot timing, slight focus imperfection and natural motion softness. No HDR, no glossy commercial lighting, no perfect digital sharpness, no crushed blacks, no orange-and-teal grading."

  step :photo_1, Input, slot: 1
  step :photo_2, Input, slot: 2
  step :film_1, AiImage, from: :photo_1, prompt: FILM
  step :film_2, AiImage, from: :photo_2, prompt: FILM
  step :text_1, TextOverlay, from: :film_1, body: "This bank holiday we work as usual", position: "top_center", size: "L", style: "shade"
  step :text_2, TextOverlay, from: :film_2, body: "Tap link below to book", position: "middle_center", size: "L", style: "none"
  step :story, Output, from: %i[text_1 text_2], format: "story"
end
