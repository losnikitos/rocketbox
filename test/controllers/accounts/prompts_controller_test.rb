# frozen_string_literal: true

require "test_helper"

class Accounts::PromptsControllerTest < ActionDispatch::IntegrationTest
  test "non-admins are redirected" do
    sign_in_as(users(:lazaro_nixon))
    get prompts_url
    assert_redirected_to root_url
  end

  test "admin creates a prompt with examples, removes one and adds more on update" do
    @admin = sign_in_as(users(:admin_user))
    get prompts_url(account: @admin.id)
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", prompts_path(account: @admin.id), text: /Prompts/

    post prompts_url, params: { prompt: { name: "Story teaser", kind: "audio", body: "p" } }
    assert_response :unprocessable_entity
    assert_select "li", text: "Kind is not included in the list"

    assert_difference -> { Prompt.video.count } do
      post prompts_url, params: { prompt: { name: "Second cinematic", kind: "video", body: "Neon night vibe", tag_id: tags(:interior).id } }
    end
    assert_equal "Neon night vibe", Prompt.find_by!(name: "Second cinematic").body

    get new_prompt_url(account: @admin.id)
    assert_select "input[type=radio][name='prompt[kind]'][value=image][checked]"
    assert_select "input[type=radio][name='prompt[kind]'][value=video]"

    post prompts_url, params: { prompt: { name: "Story teaser", body: "Film look", tag_id: tags(:interior).id, examples: [ image("a.jpg"), image("b.jpg") ] } }
    assert_redirected_to prompts_url(account: @admin.id)
    prompt = Prompt.find_by!(name: "Story teaser")
    assert prompt.image?
    assert_equal %w[a.jpg b.jpg], prompt.examples.map { it.filename.to_s }.sort

    kept, removed = prompt.examples.sort_by { it.filename.to_s }
    get edit_prompt_url(prompt, account: @admin.id)
    assert_select "input[type=hidden][name='prompt[examples][]'][form=prompt_form][value='']", count: 1
    assert_select "input[type=hidden][name='prompt[examples][]'][form=prompt_form][value=?]", kept.signed_id
    assert_select "input[type=hidden][name='prompt[examples][]'][form=prompt_form][value=?]", removed.signed_id
    assert_select "li button[data-action='file-preview#remove']", count: 2
    assert_select "form[action*='examples']", count: 0
    assert_select "textarea[name='prompt[body]']", text: "Film look"

    patch prompt_url(prompt), params: { prompt: { name: "Story teaser", kind: "video", examples: [ "", kept.signed_id, image("c.jpg") ] } }
    assert_redirected_to prompts_url(account: @admin.id)
    assert prompt.reload.video?
    assert_equal %w[a.jpg c.jpg], prompt.examples.map { it.filename.to_s }.sort

    patch prompt_url(prompt), params: { prompt: { name: "Story teaser", examples: [ "" ] } }
    assert_empty prompt.reload.examples
  end

  test "admin sets default options; the kind refresh swaps image options for video ones" do
    @admin = sign_in_as(users(:admin_user))

    get new_prompt_url(account: @admin.id)
    assert_select "turbo-frame#generation_options input[name='prompt[options][model]'][value='gpt-image-2.5-flare'][checked]"
    assert_equal %w[gpt-image-2.5-flare gpt-image-2 grok-imagine-image-2.0], css_select("input[name='prompt[options][model]']").map { it["value"] }
    assert_select "[role=img][aria-label='Price £££']", 1
    assert_select "button[name=refresh][formaction=?][formmethod=get][data-turbo-frame=generation_options]", new_prompt_path(account: @admin.id)

    get new_prompt_url(account: @admin.id, prompt: { kind: "video", options: { model: "gpt-image-2", aspect_ratio: "4:5" } })
    assert_select "input[name='prompt[options][model]'][value='grok-imagine-video-1.5'][checked]"
    assert_select "select[name='prompt[options][aspect_ratio]'] option[selected]", text: "9:16"
    assert_select "select[name='prompt[options][duration]'] option[selected]", text: "8 s"

    post prompts_url, params: { prompt: { name: "Square", body: "p", tag_id: tags(:interior).id,
      options: { model: "gpt-image-2", aspect_ratio: "1:1", resolution: "4k", quality: "" } } }
    prompt = Prompt.find_by!(name: "Square")
    assert_equal({ "model" => "gpt-image-2", "aspect_ratio" => "1:1", "resolution" => "4k" }, prompt.options)

    get edit_prompt_url(prompt, account: @admin.id)
    assert_select "input[name='prompt[options][aspect_ratio]'][value='1:1'][checked]"
    assert_select "button[name=refresh][formaction=?]", edit_prompt_path(prompt, account: @admin.id)

    patch prompt_url(prompt), params: { prompt: { options: { model: "gpt-image-2", aspect_ratio: "2:1" } } }
    assert_response :unprocessable_entity
    assert_select "li", text: /Aspect ratio 2:1 isn't available/
  end

  test "prompts with generations can't be removed" do
    @admin = sign_in_as(users(:admin_user))
    prompt = prompts(:cinematic)
    prompt.generations.create!(source_media: story_image, generated_media: story_image)

    get prompts_url(account: @admin.id)
    assert_select "##{dom_id(prompt)} [popover] a[href^='/admin/prompts/#{prompt.id}']"
    assert_select "##{dom_id(prompt)} [popover] a[href^='/app/prompts/#{prompt.id}?'][data-turbo-method=delete]"
    get admin_prompt_path(prompt)
    assert_response :success

    assert_no_difference -> { Prompt.count } do
      delete prompt_url(prompt)
    end
    assert_redirected_to prompts_url(account: @admin.id)
    assert_difference -> { Prompt.count }, -1 do
      delete prompt_url(prompts(:before_after))
    end
  end

  test "index tabs filter by tag, set on create and edit" do
    @admin = sign_in_as(users(:admin_user))
    get prompts_url(account: @admin.id, tag: "exterior")
    assert_select "nav[aria-label='Secondary'] a[aria-selected='true']", text: /Exterior/
    assert_select "nav[aria-label='Secondary'] a", text: /Interior\s+1/
    assert_select "##{dom_id(prompts(:cinematic))}", count: 0

    get prompts_url(account: @admin.id, tag: "interior")
    assert_select "##{dom_id(prompts(:cinematic))}"

    card = tags(:business_card)
    post prompts_url, params: { prompt: { name: "Card promo", body: "p", tag_id: card.id } }
    prompt = Prompt.find_by!(name: "Card promo")
    assert_equal card, prompt.tag

    get edit_prompt_url(prompt, account: @admin.id)
    assert_select "select[name='prompt[tag_id]'] option[selected][value=?]", card.id.to_s
    patch prompt_url(prompt), params: { prompt: { tag_id: tags(:exterior).id } }
    assert_equal tags(:exterior), prompt.reload.tag

    post prompts_url, params: { prompt: { name: "Bad", body: "p", tag_id: 0 } }
    assert_response :unprocessable_entity
  end

  private

    def image(name)
      Rack::Test::UploadedFile.new(StringIO.new("img"), "image/jpeg", original_filename: name)
    end

    def story_image
      LibraryMedia.create!(kind: "photo", user: users(:lazaro_nixon)).tap do
        it.file.attach(io: StringIO.new("img"), filename: "s.jpg", content_type: "image/jpeg")
      end
    end
end
