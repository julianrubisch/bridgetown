# frozen_string_literal: true

module Bridgetown
  class AttributeChangeset
    def initialize(model)
      @model = model
      @changeset = Set.new
    end

    def will_change!(attr)
      @changeset << attr
    end

    def changes
      @changeset
    end

    def clear!
      @changeset.clear
    end
  end
end
