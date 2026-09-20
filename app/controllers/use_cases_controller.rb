# frozen_string_literal: true

class UseCasesController < ApplicationController
  REGISTRY = {
    "barbershops" => {
      label: "Barbershops",
      headline: "Post the cut while you’re still finishing the fade.",
      lede: "You send a photo from the chair. We turn it into a reel and put it on your socials so the next booking finds you.",
      demos: [
        { photo: "/use-cases/barbershops/alan.jpg", video: "/use-cases/barbershops/alan.mp4", caption: "Alan" },
        { photo: "/use-cases/barbershops/bob.jpg", video: "/use-cases/barbershops/bob.mp4", caption: "Bob" }
      ],
      account: {
        username: "fadehouse",
        display_name: "Fade House",
        bio: "Cuts · fades · same-day appointments",
        posts: 128,
        followers: "4.2K",
        following: 312,
        avatar: "/use-cases/barbershops/account/avatar.jpg",
        grid: [
          { src: "/use-cases/barbershops/account/01.jpg", reel: true },
          { src: "/use-cases/barbershops/account/02.jpg", reel: true },
          { src: "/use-cases/barbershops/account/03.jpg" },
          { src: "/use-cases/barbershops/account/04.jpg", reel: true },
          { src: "/use-cases/barbershops/account/05.jpg" },
          { src: "/use-cases/barbershops/account/06.jpg", reel: true },
          { src: "/use-cases/barbershops/account/07.jpg" },
          { src: "/use-cases/barbershops/account/08.jpg", reel: true },
          { src: "/use-cases/barbershops/account/09.jpg", reel: true }
        ]
      }
    },
    "nail-salons" => {
      label: "Nail salons",
      headline: "Turn each set into a story without leaving the chair.",
      lede: "Snap the finished nails. We edit, caption, and post so your feed stays full while you stay booked.",
      demos: [
        { photo: "/use-cases/nail-salons/set-photo.png", video: "/use-cases/nail-salons/set-reel.png", caption: "Set", video_is_image: true },
        { photo: "/use-cases/nail-salons/art-photo.png", video: "/use-cases/nail-salons/art-reel.png", caption: "Art", video_is_image: true }
      ]
    },
    "restaurants" => {
      label: "Restaurants",
      headline: "Plate it once. We put it on the feed.",
      lede: "Send a photo of the dish. We cut a short clip that makes people hungry and brings them through the door.",
      demos: [
        { photo: "/use-cases/restaurants/plate-photo.png", video: "/use-cases/restaurants/plate-reel.png", caption: "Plate", video_is_image: true },
        { photo: "/use-cases/restaurants/special-photo.png", video: "/use-cases/restaurants/special-reel.png", caption: "Special", video_is_image: true }
      ]
    },
    "pet-groomers" => {
      label: "Pet groomers",
      headline: "Before-and-after that books the next appointment.",
      lede: "Send the after shot. We build a reel that shows the transformation and keeps the calendar full.",
      demos: [
        { photo: "/use-cases/pet-groomers/fluff-photo.png", video: "/use-cases/pet-groomers/fluff-reel.png", caption: "Fluff", video_is_image: true },
        { photo: "/use-cases/pet-groomers/trim-photo.png", video: "/use-cases/pet-groomers/trim-reel.png", caption: "Trim", video_is_image: true }
      ]
    },
    "auto-detailers" => {
      label: "Auto detailers",
      headline: "Show the shine. Skip the content slog.",
      lede: "Photograph the finish. We turn it into a reel that sells the detail while you move to the next bay.",
      demos: [
        { photo: "/use-cases/auto-detailers/shine-photo.png", video: "/use-cases/auto-detailers/shine-reel.png", caption: "Shine", video_is_image: true },
        { photo: "/use-cases/auto-detailers/interior-photo.png", video: "/use-cases/auto-detailers/interior-reel.png", caption: "Interior", video_is_image: true }
      ]
    }
  }.freeze

  def show
    @use_case = REGISTRY[params[:slug]]
    return head :not_found unless @use_case

    @slug = params[:slug]
  end
end
