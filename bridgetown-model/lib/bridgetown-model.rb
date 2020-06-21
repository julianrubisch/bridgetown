# frozen_string_literal: true

require "bridgetown-core"
require "bridgetown-core/version"

module Bridgetown
  autoload :ContentModel, "bridgetown-model/content_model"

  Document.class_eval do
    def to_model
      ContentModel.new_with_document(self)
    end
  end

  Page.class_eval do
    def to_model
      ContentModel.new_with_document(self)
    end
  end
end
