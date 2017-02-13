require 'rails/generators/base'

module RailsImporter
  class ImporterGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("../../templates", __FILE__)

    def generate_importer
      @importer_name = file_name.classify
      template "generic_importer.erb", File.join('app/importers', "#{file_name.underscore}_importer.rb")
    end
  end
end