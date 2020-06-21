# frozen_string_literal: true

module Bridgetown
  module ContentModels
    class Page < Bridgetown::ContentModel
    end

    class Post < Bridgetown::ContentModel
    end
  end

  ContentStrategy.add_klass(ContentModels::Page, collection_labeled: :pages)
  ContentStrategy.add_klass(ContentModels::Post, collection_labeled: :posts)
end
