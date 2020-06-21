# frozen_string_literal: true

require "base64"
require "active_model"

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

  class ContentModel
    include ActiveModel::Model
    extend ActiveModel::Callbacks
    define_model_callbacks :save, :destroy

    def self.new_with_document(document)
      new.tap do |model|
        model.wrap_document(document)
      end
    end

    def self.new_in_collection(collection)
      new_with_document(Document.new(nil, collection: collection))
    end

    def self.new_in_pages(site)
      new_with_document(Bridgetown::PageWithoutAFile.new(site, site.source, "", ""))
    end

    def self.find_in_collection(id, collection)
      find_in_group(id, collection.docs)
    end

    def self.find_in_pages(id, pages)
      find_in_group(id, pages)
    end

    def self.find_in_group(id, group)
      id = Base64.urlsafe_decode64(id) unless id.include?(".")
      document = group.find { |doc| doc.relative_path == id }
      new_with_document(document) if document
    end

    def initialize(attributes = {})
      super

      @_changeset = AttributeChangeset.new(self)
    end

    def wrap_document(document_to_wrap)
      @_document = document_to_wrap
    end

    def wrapped_document
      @_document
    end

    def attributes
      @_document&.data || {}
    end

    def id
      return nil unless persisted?

      Base64.urlsafe_encode64(wrapped_document.relative_path, padding: false)
    end

    def persisted?
      wrapped_document.path.present? && File.exist?(absolute_path_in_source_dir)
    end

    def absolute_path_in_source_dir
      wrapped_document.site.in_source_dir(wrapped_document.path)
    end

    def content
      wrapped_document.content
    end

    def content=(new_content)
      wrapped_document.content = new_content
    end

    def generate_new_slug
      prefix = if wrapped_document.respond_to?(:collection) &&
          wrapped_document.collection.label == "posts"
                 wrapped_document.date.strftime("%Y-%m-%d-")
               else
                 ""
               end

      # TODO: allow the new file extension to be customizable
      prefix + if respond_to?(:title)
                 Utils.slugify(title.to_s) + ".md"
               elsif respond_to?(:name)
                 Utils.slugify(name.to_s) + ".md"
               else
                 "untitled-#{Time.now.to_i}.md"
               end
    end

    def save
      content_dir = if wrapped_document.respond_to? :collection
                      collection = wrapped_document.collection
                      collection.directory
                    else
                      wrapped_document.site.source
                    end

      run_callbacks :save do
        if wrapped_document.path.blank?
          wrapped_document.process_absolute_path(
            File.join(
              content_dir,
              generate_new_slug
            )
          )
        end

        # Create folders if necessary
        dir = File.dirname(absolute_path_in_source_dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        new_file_contents = file_output_to_write

        File.open(absolute_path_in_source_dir, "w") do |f|
          f.write(new_file_contents)
        end

        @_changeset.clear!

        true
      end
    end

    def file_output_to_write
      processed_front_matter.to_yaml + "---" + "\n\n" + content.to_s
    end

    def processed_front_matter
      if persisted?
        file_contents = File.read(
          absolute_path_in_source_dir,
          Utils.merged_file_read_opts(wrapped_document.site, {})
        )
        if file_match = file_contents.match(Document::YAML_FRONT_MATTER_REGEXP)
          yaml_data = SafeYAML.load(file_match.captures[0])
        else
          raise Errors::FatalException,
                "YAML front matter not found in #{absolute_path_in_source_dir}"
        end
        attribute_changes.each do |attr|
          yaml_data[attr.to_s] = send(attr)
        end
        yaml_data.each_key do |key|
          yaml_data.delete(key) unless attributes.key?(key)
        end
        yaml_data
      else
        attributes.deep_stringify_keys
      end
    end

    def attribute_changes
      @_changeset.changes
    end

    def attribute_will_change!(key)
      @_changeset.will_change!(key)
    end

    def respond_to_missing?(method_name, include_private = false)
      attributes.include?(method_name) || method_name.to_s.end_with?("=") || super
    end

    def method_missing(method_name, *args, &block)
      return attributes[method_name] if attributes.include?(method_name)

      key = method_name.to_s
      if key.end_with?("=")
        attribute_will_change!(key.chop!)
        attributes[key] = args.first
        return attributes[key]
      end

      super
    end
  end
end
