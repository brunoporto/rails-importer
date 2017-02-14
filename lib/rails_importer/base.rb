require 'builder'
require 'spreadsheet'

module RailsImporter
  class Base
    class_attribute :importers

    class << self
      def import(file, *args)
        context = args.try(:context) || :default
        result = []
        begin
          ext = (File.extname(file.path)[1..-1] rescue nil)
          if file.respond_to?(:path) and self.file_types.include?(ext.to_sym)
            rows = self.send("import_from_#{ext}", file)
            if rows.present? and rows.is_a?(Array)
              result = rows.map do |record|
                self.importers[context][:each_record].call(record, *args) if self.importers[context][:each_record].is_a?(Proc)
              end.compact
            end
          else
            I18n.t(:invalid_file_type, file_types: self.file_types.join(', '), scope: [:importer, :error])
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

      def importer(name=:default, &block)
        (self.importers ||= {})[name] ||= {fields: [], xml_structure: [:records, :record], each_record: nil}
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

      def each_record(&block)
        importer_value(:each_record, block)
      end

      private
      def import_from_csv(file, context=:default)
        records = []
        line = 0
        CSV.foreach(file.path, {:headers => false, :col_sep => ';', :force_quotes => true}) do |row|
          if line>0
            records << object_values(row, context) unless array_blank?(row)
          end
          line+=1
        end
        records
      end

      def import_from_xml(file, context=:default)
        records = []
        xml_structure = self.importers[context][:xml_structure]
        xml = Hash.from_xml(file.read)
        xml_structure.each do |node|
          xml = xml[node.to_s]
        end
        xml.each do |elem|
          records << object_values(elem.values, context) unless array_blank?(elem.values)
        end
        records
      end

      def import_from_xls(file, context=:default)
        records = []
        Spreadsheet.client_encoding = 'UTF-8'
        document = Spreadsheet.open(file.path)
        spreadsheet = document.worksheet 0
        spreadsheet.each_with_index do |row, i|
          next unless i>0
          records << object_values(row, context) unless array_blank?(row)
        end
        records
      end

      def object_values(array, context=:default)
        attributes = self.importers[context][:fields]
        attributes = attributes.keys if attributes.is_a?(Hash)
        args = array[0...attributes.size]
        hValues = Hash[attributes.zip(args)]
        attributes.each do |attr|
          if hValues[attr].present?
            if hValues[attr].is_a?(Numeric)
              hValues[attr] = hValues[attr].to_i if hValues[attr].modulo(1).zero?
              hValues[attr] = (hValues[attr].to_s.strip rescue '#ERRO AO CONVERTER NUMERO PARA TEXTO')
            elsif hValues[attr].is_a?(Date)
              hValues[attr] = (I18n.l(hValues[attr], format: '%d/%m/%Y') rescue hValues[attr]).to_s
            elsif hValues[attr].is_a?(DateTime)
              hValues[attr] = (I18n.l(hValues[attr], format: '%d/%m/%Y %H:%i:%s') rescue hValues[attr]).to_s
            else
              #PARA QUALQUER OUTRO VALOR, FORÇA CONVERTER PARA STRING
              hValues[attr] = (hValues[attr].to_s.strip rescue '')
            end
          else
            hValues[attr] = ''
          end
        end
        OpenStruct.new(hValues)
      end

      def array_blank?(array)
        array.all? {|i|i.nil? or i==''}
      end

      def importer_value(key, attributes)
        if attributes.present?
          if key==:fields
            self.importers[@importer_name][key] = (attributes.first.is_a?(Hash) ? attributes.inject(:merge) : attributes)
          else
            self.importers[@importer_name][key] = attributes
          end
        else
          self.importers[@importer_name][key]
        end
      end
    end

  end
end