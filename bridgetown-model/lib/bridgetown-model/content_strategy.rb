# frozen_string_literal: true

module Bridgetown
  class ContentStrategy
    @strategies = ActiveSupport::HashWithIndifferentAccess.new

    def self.add_klass(klass, collection_labeled:)
      @strategies[collection_labeled] = klass
    end

    def self.klass_for_document(document)
      if document.respond_to?(:collection)
        klass_for_label document.collection.label
      else
        klass_for_label :pages
      end
    end

    def self.klass_for_label(label)
      @strategies.fetch label, ContentModel
    end
  end
end
