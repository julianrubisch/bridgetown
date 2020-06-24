# frozen_string_literal: true

require "base64"
require "active_model"
require "active_support/core_ext/date_time"

module Bridgetown
  class ContentModel
    include ActiveModel::Model
    extend ActiveModel::Callbacks
    define_model_callbacks :save, :destroy

    def self.new_with_document(document)
      ContentStrategy.klass_for_document(document).new.tap do |model|
        model.wrap_document(document)
      end
    end

    def self.new_in_collection(collection)
      new_with_document(Document.new(nil, collection: collection))
    end

    def self.new_in_pages(site)
      new_with_document(Bridgetown::PageWithoutAFile.new(site, site.source, "", ""))
    end

    def self.new_via_label(label, site:)
      label = label.to_s
      group = if label == "page"
                "pages"
              elsif label == "pages"
                label
              elsif site.collections[label]
                label
              elsif site.collections[label.pluralize]
                label.pluralize
              else
                raise Errors::FatalException,
                      "Collection could not be found for `#{label}'"
              end
      if group == "pages"
        new_in_pages site
      else
        new_in_collection site.collections[group]
      end
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

    def self.group_for_label(label, site:)
      label = label.to_s
      group = if label == "page"
                "pages"
              elsif label == "pages"
                label
              elsif site.collections[label]
                label
              elsif site.collections[label.pluralize]
                label.pluralize
              else
                raise Errors::FatalException,
                      "Collection could not be found for `#{label}'"
              end
      if group == "pages"
        site.pages
      else
        site.collections[group].docs
      end
    end

    def self.models_for_label(label, site:)
      group_for_label(label, site: site).map(&:to_model).select(&:persisted?)
    end

    def self.find(id, label:, site:)
      find_in_group id, group_for_label(label, site: site)
    end

    def self.find_all(label, site:, order_by: :posted_datetime, order_direction: :desc)
      models = models_for_label(label, site: site)

      if order_by.to_s == "use_configured"
        models
      else
        begin
          models.sort_by! do |content_model|
            content_model.send(order_by)
          end
        rescue ArgumentError => e
          Bridgetown.logger.warn "Sorting #{label} by #{order_by}, value comparison failed"
          models.sort_by!(&:posted_datetime)
        end
        order_direction.to_s == "desc" ? models.reverse : models
      end
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

    def posted_datetime
      if attributes.include?(:date) && date
        date.to_datetime
      elsif matched = File.basename(wrapped_document.path.to_s).match(%r!^[0-9]+-[0-9]+-[0-9]+!)
        matched[0].to_datetime
      elsif persisted?
        File.stat(absolute_path_in_source_dir).mtime
      else
        wrapped_document.site.time
      end
    end

    def url
      wrapped_document.url
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
                 wrapped_document.date.to_datetime.strftime("%Y-%m-%d-")
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
      if wrapped_document.yaml_file?
        processed_front_matter.to_yaml
      else
        processed_front_matter.to_yaml + "---" + "\n\n" + content.to_s
      end
    end

    def processed_front_matter
      if persisted?
        file_contents = File.read(
          absolute_path_in_source_dir,
          Utils.merged_file_read_opts(wrapped_document.site, {})
        )
        if wrapped_document.yaml_file?
          yaml_data = SafeYAML.load(file_contents)
        elsif file_match = file_contents.match(Document::YAML_FRONT_MATTER_REGEXP)
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
        attributes.to_h.deep_stringify_keys
      end
    end

    def destroy
      run_callbacks :destroy do
        if persisted?
          File.delete(absolute_path_in_source_dir)
          wrapped_document.process_absolute_path("")

          true
        end
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

    def method_missing(method_name, *args)
      return attributes[method_name] if attributes.include?(method_name)

      key = method_name.to_s
      if key.end_with?("=")
        attribute_will_change!(key.chop!)
        attributes[key] = args.first
        return attributes[key]
      end

      Bridgetown.logger.warn "key `#{method_name}' not found in attributes for" \
                             " #{wrapped_document.relative_path}"
      nil
    end

    def fetch(key, default = nil)
      respond_to?(key) ? send(key) : default
    end
  end
end

require "bridgetown-model/content_model_classes"
