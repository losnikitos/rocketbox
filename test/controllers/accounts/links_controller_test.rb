# frozen_string_literal: true

require "test_helper"

class Accounts::LinksControllerTest < ActionDispatch::IntegrationTest
  PHOTO = "https://cdn.example.com/cut.jpg"
  VIDEO = "https://cdn.example.com/fade.mp4"
  LOGO = "https://cdn.example.com/logo.png"

  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @link = @user.links.create!(url: "https://www.fresha.com/a/lazaro")
    @crawl = @link.crawls.create!(
      provider: "firecrawl", data_instruction: "x", status: "done",
      extracted: CrawlBusiness.normalize(
        "business_name" => " Lazaro Fades ", "phone" => "+44 20 0000", "address" => "", "logo_url" => LOGO,
        "photo_urls" => [ PHOTO, "data:image/png;base64,AAA", PHOTO ], "video_urls" => "#{VIDEO} not-a-url"
      )
    )
    @crawl.create_suggestions!

    @original_fetch = RemoteFile.method(:fetch)
    bytes = file_fixture("logo.png").binread
    RemoteFile.define_singleton_method(:fetch) do |url|
      StringIO.new(bytes).tap do |io|
        io.define_singleton_method(:content_type) { url.end_with?(".mp4") ? "video/mp4" : "image/png" }
      end
    end
  end

  teardown do
    RemoteFile.define_singleton_method(:fetch, @original_fetch)
  end

  test "normalizes extracted data" do
    assert_equal "Lazaro Fades", @crawl.extracted["business_name"]
    assert_nil @crawl.extracted["address"]
    assert_equal [ PHOTO ], @crawl.photo_urls
    assert_equal [ VIDEO ], @crawl.video_urls
    assert_equal({ business_name: "Lazaro Fades", phone: "+44 20 0000" }, @crawl.account_attributes)
    assert_equal "Lazaro Fades", @link.title

    google = "https://lh3.googleusercontent.com/gps-cs-s/abc"
    assert_equal [ "#{google}=s0", PHOTO ], CrawlBusiness.http_urls("#{google}=w408-h544-k-no,#{PHOTO},")
    tripadvisor = "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/07/5c/7a/9a/kilis-kitchen.jpg"
    assert_equal [ tripadvisor ], CrawlBusiness.http_urls([ "#{tripadvisor}?w=300&h=200&s=1", "#{tripadvisor}?w=900&h=500&s=1" ])
  end

  test "finds urls in message text" do
    assert_equal [ "https://a.com/x", "http://b.co" ], Link.urls_in("see https://a.com/x, and (http://b.co). https://a.com/x!")
    assert_empty Link.urls_in("no links here")
  end

  test "index lists links and adds new ones" do
    get links_url

    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", links_path, text: /Links/
    assert_select "a[href=?]", link_path(@link), text: /Lazaro Fades/

    post links_url, params: { link: { url: "https://trustpilot.com/review/lazaro" } }
    link = @user.links.order(:id).last
    assert_redirected_to link_url(link)
    assert_equal "app", link.source

    assert_no_difference -> { Link.count } do
      post links_url, params: { link: { url: "ftp://example.com" } }
      post links_url, params: { link: { url: link.url } }
    end
    assert_response :unprocessable_entity
  end

  test "removes a link with its crawls, only your own" do
    get links_url
    assert_select "form[action=?] input[name='_method'][value='delete']", link_path(@link)

    sign_in_as(users(:admin_user))
    delete link_url(@link)
    assert_response :not_found

    sign_in_as(@user)
    assert_difference -> { Link.count } => -1, -> { Crawl.count } => -1 do
      delete link_url(@link)
    end
    assert_redirected_to links_url
  end

  test "show prefills the default data instruction for a new link" do
    link = @user.links.create!(url: "https://example.com")
    get link_url(link)

    assert_response :success
    assert_select "textarea[name='crawl[data_instruction]']", text: prompts(:crawl_business).body

    get link_url(@link)
    assert_response :success
    assert_select "form[action=?]", apply_link_crawl_path(@link, @crawl), count: 2
    assert_select "form[action^=?][action$='/apply']", "/app/links/#{@link.id}/suggestions/", count: 5
    assert_select "textarea[name='crawl[data_instruction]']", text: "x"
  end

  test "creates one suggestion per change and skips what the account already has" do
    assert_equal %w[business_name phone logo photo video], @crawl.suggestions.map(&:key)
    assert @crawl.suggestions.all?(&:pending?)
    assert_equal [ "Lazaro Fades", LOGO, PHOTO ], @crawl.suggestions.to_a.values_at(0, 2, 3).map(&:value)

    @user.update!(phone: "+44 20 0000")
    @user.library_media.import_url!(PHOTO)
    crawl = @link.crawls.create!(provider: "firecrawl", data_instruction: "x", status: "done", extracted: @crawl.extracted)
    crawl.create_suggestions!
    assert_equal %w[business_name logo video], crawl.suggestions.map(&:key)
  end

  test "crawl create enqueues the crawl" do
    assert_enqueued_with(job: CrawlBusinessJob) do
      post link_crawls_url(@link), params: { crawl: { provider: "getbro", data_instruction: "Find it" } }
    end
    assert_redirected_to link_url(@link)
    assert @link.crawls.last.pending?
  end

  test "applies one suggestion at a time" do
    patch apply_link_suggestion_url(@link, suggestion("phone"))

    assert_redirected_to link_url(@link)
    @user.reload
    assert_equal "+44 20 0000", @user.phone
    assert_equal "Lazaro Cuts", @user.business_name
    assert_not @user.logo.attached?
    assert_equal 0, @user.library_media.count
    assert_equal %w[pending applied pending pending pending], @crawl.suggestions.map(&:status)
  end

  test "rejected suggestions stay visible and are skipped by apply everything" do
    patch reject_link_suggestion_url(@link, suggestion("phone"))
    patch reject_link_suggestion_url(@link, suggestion("logo"))
    assert_redirected_to link_url(@link)
    assert suggestion("phone").rejected?

    get link_url(@link)
    assert_select "dd del", text: "+44 20 0000"
    assert_select "img[alt='Logo from page (rejected)']"
    assert_select "form[action=?]", reject_link_suggestion_path(@link, suggestion("phone")), count: 0
    assert_select "form[action=?]", apply_link_suggestion_path(@link, suggestion("phone"))

    patch apply_link_crawl_url(@link, @crawl)
    @user.reload
    assert_equal "Lazaro Fades", @user.business_name
    assert_nil @user.phone
    assert_not @user.logo.attached?
    assert_equal %w[applied rejected rejected applied applied], @crawl.suggestions.map(&:status)
  end

  test "applies everything and skips media already in the library" do
    patch apply_link_suggestion_url(@link, suggestion("photo"))
    assert_redirected_to link_url(@link, anchor: "suggestion-#{suggestion("photo").id}")
    assert_equal 1, @user.library_media.count

    patch apply_link_crawl_url(@link, @crawl)

    assert_redirected_to link_url(@link)
    @user.reload
    assert_equal "Lazaro Fades", @user.business_name
    assert @user.logo.attached?
    assert_equal %w[photo video], @user.library_media.order(:id).pluck(:kind)
    assert_equal [ PHOTO, VIDEO ], @user.library_media.order(:id).pluck(:source_url)
    assert @crawl.suggestions.all?(&:applied?)

    get link_url(@link)
    assert_select "button", text: "Everything applied"
    assert_select "a[href=?]", library_upload_path(@user.library_media.first), text: /In library/
  end

  test "add all to library applies only photos and videos" do
    patch apply_link_crawl_url(@link, @crawl), params: { media: 1 }

    assert_redirected_to link_url(@link)
    assert_equal [ PHOTO, VIDEO ], @user.library_media.order(:id).pluck(:source_url)
    assert_not @user.reload.logo.attached?
    assert_equal %w[pending pending pending applied applied], @crawl.suggestions.map(&:status)

    get link_url(@link)
    assert_select "button", text: /Add all to library/, count: 0
  end

  test "failed downloads keep the suggestion pending" do
    RemoteFile.define_singleton_method(:fetch) { |_url| raise RemoteFile::Error, "Timed out." }
    patch apply_link_suggestion_url(@link, suggestion("logo"))

    assert_redirected_to link_url(@link)
    assert_match "Timed out.", flash[:alert]
    assert suggestion("logo").pending?
  end

  test "other users' links and suggestions are hidden" do
    admin = sign_in_as(users(:admin_user))
    get link_url(@link, account: admin.id)
    assert_response :not_found

    patch apply_link_suggestion_url(@link, suggestion("phone"))
    assert_response :not_found
    assert suggestion("phone").pending?
  end

  test "remote files refuse private addresses" do
    RemoteFile.define_singleton_method(:fetch, @original_fetch)
    assert_raises(RemoteFile::Error) { RemoteFile.fetch("http://127.0.0.1/secret") }
    assert_raises(RemoteFile::Error) { RemoteFile.fetch("file:///etc/passwd") }
  end

  private

    def suggestion(key)
      @crawl.suggestions.find_by!(key: key)
    end
end
