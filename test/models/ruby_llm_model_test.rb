# frozen_string_literal: true

require "test_helper"

class RubyLlmModelTest < ActiveSupport::TestCase
  test "refresh keeps hand-set modalities when the registry has none" do
    registry = RubyLLM::Models.new([ RubyLLM::Model.new(id: "gpt-image-2", provider: "openai", name: "gpt-image-2") ])
    RubyLLM::ActiveRecord::Model.save_to_database(registry)

    model = RubyLLM::ActiveRecord::Model.find_by!(provider: "openai", model_id: "gpt-image-2")
    assert_equal :image, model.type
    assert model.enabled
  end
end
