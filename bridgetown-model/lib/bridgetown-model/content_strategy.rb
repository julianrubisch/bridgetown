# frozen_string_literal: true

module Bridgetown
  class ContentStrategy
    @strategies = ActiveSupport::HashWithIndifferentAccess.new

    def self.add_klass(klass, collection_labeled:)
      @strategies[collection_labeled] = klass
    end

    def self.klass_for_document(document)
      if document.respond_to?(:collection)
        @strategies.fetch(document.collection.label, ContentModel)
      else
        @strategies.fetch(:pages, ContentModel)
      end
    end
  end
end
