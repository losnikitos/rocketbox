# frozen_string_literal: true

require "test_helper"

class Accounts::CrawlsControllerTest < ActionDispatch::IntegrationTest
  PHOTO = "https://cdn.example.com/cut.jpg"
  VIDEO = "https://cdn.example.com/fade.mp4"
  LOGO = "https://cdn.example.com/logo.png"

  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @crawl = @user.crawls.create!(
      url: "https://www.fresha.com/a/lazaro", provider: "firecrawl", data_instruction: "x", status: "done",
      extracted: CrawlBusiness.normalize(
        "business_name" => " Lazaro Fades ", "phone" => "+44 20 0000", "address" => "", "logo_url" => LOGO,
        "photo_urls" => [ PHOTO, "data:image/png;base64,AAA", PHOTO ], "video_urls" => "#{VIDEO} not-a-url"
      )
    )

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

    google = "https://lh3.googleusercontent.com/gps-cs-s/abc"
    assert_equal [ "#{google}=s0", PHOTO ], CrawlBusiness.http_urls("#{google}=w408-h544-k-no,#{PHOTO},")
    tripadvisor = "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/07/5c/7a/9a/kilis-kitchen.jpg"
    assert_equal [ tripadvisor ], CrawlBusiness.http_urls([ "#{tripadvisor}?w=300&h=200&s=1", "#{tripadvisor}?w=900&h=500&s=1" ])
  end

  test "index prefills the default data instruction" do
    get crawls_url

    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", crawls_path, text: /Crawl/
    assert_select "textarea[name='crawl[data_instruction]']", text: prompts(:crawl_business).body
  end

  test "create enqueues the crawl and rejects bad urls" do
    assert_enqueued_with(job: CrawlBusinessJob) do
      post crawls_url, params: { crawl: { url: "https://example.com", provider: "getbro", data_instruction: "Find it" } }
    end
    crawl = @user.crawls.order(:id).last
    assert_redirected_to crawl_url(crawl)
    assert crawl.pending?

    assert_no_difference -> { Crawl.count } do
      post crawls_url, params: { crawl: { url: "ftp://example.com", provider: "getbro", data_instruction: "Find it" } }
    end
    assert_response :unprocessable_entity
  end

  test "applies one field at a time" do
    patch apply_crawl_url(@crawl), params: { field: "phone" }

    @user.reload
    assert_equal "+44 20 0000", @user.phone
    assert_equal "Lazaro Cuts", @user.business_name
    assert_not @user.logo.attached?
    assert_equal 0, @user.library_media.count
  end

  test "applies everything and skips media already in the library" do
    post add_media_crawl_url(@crawl), params: { url: PHOTO }
    assert_equal 1, @user.library_media.count

    patch apply_crawl_url(@crawl)

    assert_redirected_to crawl_url(@crawl)
    @user.reload
    assert_equal "Lazaro Fades", @user.business_name
    assert @user.logo.attached?
    assert_equal %w[photo video], @user.library_media.order(:id).pluck(:kind)
    assert_equal [ PHOTO, VIDEO ], @user.library_media.order(:id).pluck(:source_url)
  end

  test "add_media only takes urls from the crawl and other users' crawls are hidden" do
    post add_media_crawl_url(@crawl), params: { url: "http://169.254.169.254/latest" }
    assert_equal 0, @user.library_media.count

    sign_in_as(users(:admin_user))
    get crawl_url(@crawl)
    assert_response :not_found
  end

  test "remote files refuse private addresses" do
    RemoteFile.define_singleton_method(:fetch, @original_fetch)
    assert_raises(RemoteFile::Error) { RemoteFile.fetch("http://127.0.0.1/secret") }
    assert_raises(RemoteFile::Error) { RemoteFile.fetch("file:///etc/passwd") }
  end
end
