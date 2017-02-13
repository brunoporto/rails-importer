require 'ostruct'

module RailsImporter

  def self.included(base)
    base.extend ClassMethods

    base.define_singleton_method 'colunas' do |*args|
      @importacao_colunas = nil unless @importacao_colunas.present?
      if args.present?
        @importacao_colunas = (args.first.is_a?(Hash) ? args.inject(:merge) : args)
      else
        @importacao_colunas
      end
    end

    base.define_singleton_method 'estrutura_xml' do |*args|
      @importacao_estrutura_xml = nil unless @importacao_estrutura_xml.present?
      if args.present?
        @importacao_estrutura_xml = args
      else
        @importacao_estrutura_xml
      end
    end

    base.define_singleton_method 'para_cada_linha' do |&block|
      define_singleton_method('importar_registro') do |registro, *args|
        block.call(registro, *args)
      end
    end

  end

  def self.tipos_de_arquivos
    [:csv, :xls, :xml]
  end

  module ClassMethods

    def importacao(&block)
      block.call if block_given?
      self.class.class_eval do
        define_method :importar do |arquivo, *args|
          retorno = []
          begin
            ext = (File.extname(arquivo.path)[1..-1] rescue nil)
            if arquivo.respond_to?(:path) and RailsImporter.tipos_de_arquivos.include?(ext.to_sym)
              registros = self.send("#{ext}_para_array", arquivo)
              if registros.present? and registros.is_a?(Array)
                retorno = registros.map do |registro|
                  importar_registro(registro, *args)
                end
              end
            else
              raise "Tipo de arquivo inválido. Arquivos permitidos: #{RailsImporter.tipos_de_arquivos.join(', ')}"
            end
          rescue Exception => e
            retorno = e.message
          end
          retorno
        end
      end
    end

    private
    def csv_para_array(arquivo)
      registros = []
      linha=0
      CSV.foreach(arquivo.path, {:headers => false, :col_sep => ';', :force_quotes => true}) do |row|
        if linha>0
          registros << object_values(row) unless array_blank?(row)
        end
        linha+=1
      end
      registros
    end

    def xml_para_array(arquivo)
      registros = []
      estrutura_xml = self.send(:estrutura_xml)
      if estrutura_xml.present? and estrutura_xml.is_a?(Array) and estrutura_xml.count > 0
        xml = Hash.from_xml(arquivo.read)
        estrutura_xml.each do |node|
          xml = xml[node.to_s]
        end
        xml.each do |elem|
          registros << object_values(elem.values) unless array_blank?(elem.values)
        end
      else
        raise 'Você precisa informar a estrutura_xml no seu Model'
      end
      registros
    end

    def xls_para_array(arquivo)
      registros = []
      Spreadsheet.client_encoding = 'UTF-8'
      documento = Spreadsheet.open(arquivo.path)
      planilha = documento.worksheet 0
      planilha.each_with_index do |row, i|
        next unless i>0
        registros << object_values(row) unless array_blank?(row)
      end
      registros
    end

    def object_values(array)
      atributos = self.send(:colunas)
      atributos = atributos.keys if atributos.is_a?(Hash)
      args = array[0...atributos.size]
      hValores = Hash[atributos.zip(args)]
      #Ajustando valores inválidos
      atributos.each do |atributo|
        if hValores[atributo].present?
          if hValores[atributo].is_a?(Numeric)
            hValores[atributo] = hValores[atributo].to_i if hValores[atributo].modulo(1).zero?
            hValores[atributo] = (hValores[atributo].to_s.strip rescue '#ERRO AO CONVERTER NUMERO PARA TEXTO')
          elsif hValores[atributo].is_a?(Date)
            hValores[atributo] = (I18n.l(hValores[atributo], format: '%d/%m/%Y') rescue hValores[atributo]).to_s
          elsif hValores[atributo].is_a?(DateTime)
            hValores[atributo] = (I18n.l(hValores[atributo], format: '%d/%m/%Y %H:%i:%s') rescue hValores[atributo]).to_s
          else
            #PARA QUALQUER OUTRO VALOR, FORÇA CONVERTER PARA STRING
            hValores[atributo] = (hValores[atributo].to_s.strip rescue '')
          end
        else
          hValores[atributo] = ''
        end
      end
      OpenStruct.new(hValores)
    end

    def array_blank?(array)
      array.all? {|i|i.nil? or i==''}
    end

  end
end
