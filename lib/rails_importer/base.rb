require 'builder'
require 'spreadsheet'

module RailsImporter
  class Base
    class_attribute :importers

    class << self
      def import(file, *args)
        context = args.try(:context) || :default
        custom_fields = args.try(:fields) || nil
        result = []
        begin
          if file.respond_to?(:path)
            ext = (File.extname(file.path)[1..-1] rescue '')
            if self.file_types.include?(ext.to_sym)
              rows = self.send('import_from_%s' % ext, file, context, custom_fields)
              if rows.present? && rows.is_a?(Array)
                result = rows.map do |record|
                  self.importers[context][:each_record].call(record, *args) if self.importers[context][:each_record].is_a?(Proc)
                end.compact
              end
            else
              result = I18n.t(:invalid_file_type, file_types: self.file_types.join(', '), scope: [:importer, :error])
            end
          else
            result = I18n.t(:invalid_file, scope: [:importer, :error])
          end
        rescue Exception => e
          result = e.message
        end
        result
      end

      def file_types
        [:csv, :xls, :xml]
      end

      # def method_missing(m, *args, &block)
      #   if m =~ /_url|_path/
      #     Rails.application.routes.url_helpers.send(m, args)
      #   end
      # end

      def importer(name = :default, &block)
        (self.importers ||= {})[name] ||= {
          fields: [],
          csv_params: [headers: false, col_sep: ',', force_quotes: true],
          xml_structure: %i[records record],
          each_record: nil
        }
        @importer_name = name
        block.call if block_given?
        self.importers[name]
      end

      def fields(*attributes)
        importer_value(:fields, attributes)
      end

      def xml_structure(*attributes)
        importer_value(:xml_structure, attributes)
      end

      def csv_params(*attributes)
        options = self.importers[@importer_name][:csv_params]
        params = attributes.first
        options = options.merge(params) if params.is_a?(Hash)
        importer_value(:csv_params, options)
      end

      def each_record(&block)
        importer_value(:each_record, block)
      end

      private
      def import_from_csv(file, context = :default, custom_fields = :nil)
        records = []
        first_line = nil
        options = self.importers[context][:csv_params]
        CSV.foreach(file.path, options.merge(headers: false)) do |row|
          # Skip headers
          if first_line.nil?
            first_line = row
            next
          end
          records << object_values(row, context, custom_fields) unless array_blank?(row)
        end
        records
      end

      def import_from_xml(file, context = :default, custom_fields = :nil)
        records = []
        xml_structure = self.importers[context][:xml_structure]
        xml = Hash.from_xml(file.read)
        xml_structure.each do |node|
          xml = xml[node.to_s]
        end
        xml.each do |elem|
          records << object_values(elem.values, context, custom_fields) unless array_blank?(elem.values)
        end
        records
      end

      def import_from_xls(file, context = :default, custom_fields = :nil)
        records = []
        Spreadsheet.client_encoding = 'UTF-8'
        document = Spreadsheet.open(file.path)
        spreadsheet = document.worksheet 0
        spreadsheet.each_with_index do |row, i|
          next if i.zero?
          records << object_values(row, context, custom_fields) unless array_blank?(row)
        end
        records
      end

      def object_values(array, context = :default, custom_fields = nil)
        attributes = custom_fields || self.importers[context][:fields]
        attributes = attributes.keys if attributes.is_a?(Hash)
        values = equalize_columns_of_values(attributes, array)
        hash_values = Hash[attributes.zip(values)]
        attributes.each do |attr|
          if hash_values[attr].present?
            if hash_values[attr].is_a?(Numeric)
              hash_values[attr] = hash_values[attr].to_i if hash_values[attr].modulo(1).zero?
              hash_values[attr] = (hash_values[attr].to_s.strip rescue I18n.t(:convert_number_to_text, scope: [:importer, :error]))
            elsif hash_values[attr].is_a?(Date)
              hash_values[attr] = (I18n.l(hash_values[attr], format: '%d/%m/%Y') rescue hash_values[attr]).to_s
            elsif hash_values[attr].is_a?(DateTime)
              hash_values[attr] = (I18n.l(hash_values[attr], format: '%d/%m/%Y %H:%i:%s') rescue hash_values[attr]).to_s
            else
              #PARA QUALQUER OUTRO VALOR, FORÇA CONVERTER PARA STRING
              hash_values[attr] = (hash_values[attr].to_s.strip rescue '')
            end
          else
            hash_values[attr] = ''
          end
        end
        OpenStruct.new(hash_values)
      end

      def array_blank?(array)
        array.all?(&:blank?)
      end

      def importer_value(key, attributes)
        if attributes.present?
          if key == :fields
            self.importers[@importer_name][key] = normalize_fields(attributes)
          else
            self.importers[@importer_name][key] = attributes
          end
        else
          self.importers[@importer_name][key]
        end
      end

      def normalize_fields(attributes)
        if attributes.first.is_a?(Hash)
          attributes.inject(:merge)
        elsif attributes.first.is_a?(Array)
          attributes.flatten
        else
          attributes
        end
      end

      def equalize_columns_of_values(attributes, values=[])
        if attributes.size > values.size
          diff_size = (attributes.size - values.size).abs
          values + Array.new(diff_size, nil)
        elsif attributes.size < values.size
          values[0...attributes.size]
        else
          values
        end
      end

    end

  end
end