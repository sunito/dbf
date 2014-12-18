module DBF

  # DBF::Table is the primary interface to a single DBF file and provides
  # methods for enumerating and searching the records.
  class Table
    include Enumerable

    class InvalidHeader < StandardError; end
    class NotYetImplementedError < StandardError; end

    DBF_HEADER_SIZE = 32

    VERSIONS = {
      "02" => "FoxBase",
      "03" => "dBase III without memo file",
      "04" => "dBase IV without memo file",
      "05" => "dBase V without memo file",
      "07" => "Visual Objects 1.x",
      "30" => "Visual FoxPro",
      "31" => "Visual FoxPro with AutoIncrement field",
      "7b" => "dBase IV with memo file",
      "83" => "dBase III with memo file",
      "87" => "Visual Objects 1.x with memo file",
      "8b" => "dBase IV with memo file",
      "8e" => "dBase IV with SQL table",
      "f5" => "FoxPro with memo file",
      "fb" => "FoxPro without memo file"
    }

    FOXPRO_VERSIONS = {
      "30" => "Visual FoxPro",
      "31" => "Visual FoxPro with AutoIncrement field",
      "f5" => "FoxPro with memo file",
      "fb" => "FoxPro without memo file"
    }

    attr_reader   :version              # Internal dBase version number
    attr_reader   :total_record_count         # Total number of records
    attr_accessor :encoding             # Source encoding (for ex. :cp1251)

    # Opens a DBF::Table
    # Examples:
    #   # working with a file stored on the filesystem
    #   table = DBF::Table.new 'data.dbf'
    #
    #   # working with a misnamed memo file
    #   table = DBF::Table.new 'data.dbf', 'memo.dbt'
    #
    #   # working with a dbf in memory
    #   table = DBF::Table.new StringIO.new(dbf_data)
    #
    #   # working with a dbf and memo in memory
    #   table = DBF::Table.new StringIO.new(dbf_data), StringIO.new(memo_data)
    #
    # @param [String, StringIO] data Path to the dbf file or a StringIO object
    # @param [optional String, StringIO] memo Path to the memo file or a StringIO object
    def initialize(data, memo = nil)
      @data = open_data(data)
      get_header_info
      @memo = open_memo(data, memo)
      @indexes = {}
    end

    # @return [TrueClass, FalseClass]
    def has_memo_file?
      !!@memo
    end

    # Closes the table and memo file
    #
    # @return [TrueClass, FalseClass]
    def close
      @memo && @memo.close
      @data.close && @data.closed?
    end

    # @return String
    def filename
      File.basename @data.path
    end

    # Will enable index-enhanced find operations
    #
    # @param [Array] keys
    def add_index(keys)
      keys_unikey = array_to_unikey(keys)
      @indexes[keys_unikey] = Hash.new
    end

    # Calls block once for each record in the table. The record may be nil
    # if the record has been marked as deleted.
    #
    # @yield [nil, DBF::Record]
    def each
      @total_record_count.times {|i| yield record(i)}
    end

    # the number of active (not deleted) records
    #
    # @return Integer
    def record_count
      @total_record_count - deleted_record_count
    end

    # the number of active (not deleted) records
    #
    # @return Integer
    def deleted_record_count
      @deleted_record_count ||= (0...@total_record_count).inject(0) do |c, i|
        record_active?(i) ? c : c+1
      end
    end


    # Retrieve a record by idx number.
    # The record will be nil if it has been deleted, but not yet pruned from
    # the database.
    #
    # @param [Fixnum] idx
    # @return [DBF::Record, NilClass]
    def record(idx)
      record_active?(idx) do |raw_data|
        DBF::Record.new(raw_data, columns, version, @memo)
      end
    end

    alias_method :row, :record

    # Human readable version description
    #
    # @return [String]
    def version_description
      VERSIONS[version]
    end

    # Generate an ActiveRecord::Schema
    #
    # xBase data types are converted to generic types as follows:
    # - Number columns with no decimals are converted to :integer
    # - Number columns with decimals are converted to :float
    # - Date columns are converted to :datetime
    # - Logical columns are converted to :boolean
    # - Memo columns are converted to :text
    # - Character columns are converted to :string and the :limit option is set
    #   to the length of the character column
    #
    # Example:
    #   create_table "mydata" do |t|
    #     t.column :name, :string, :limit => 30
    #     t.column :last_update, :datetime
    #     t.column :is_active, :boolean
    #     t.column :age, :integer
    #     t.column :notes, :text
    #   end
    #
    # @return [String]
    def schema
      s = "ActiveRecord::Schema.define do\n"
      s << "  create_table \"#{File.basename(@data.path, ".*")}\" do |t|\n"
      columns.each do |column|
        s << "    t.column #{column.schema_definition}"
      end
      s << "  end\nend"
      s
    end

    # Dumps all records to a CSV file.  If no filename is given then CSV is
    # output to STDOUT.
    #
    # @param [optional String] path Defaults to STDOUT
    def to_csv(path = nil)
      csv = csv_class.new((path ? File.open(path, 'w') : $stdout), :force_quotes => true)
      csv << columns.map {|c| c.name}
      each {|record| csv << record.to_a}
    end

    # Find records using a simple ActiveRecord-like syntax.
    #
    # Examples:
    #   table = DBF::Table.new 'mydata.dbf'
    #
    #   # Find record number 5
    #   table.find(5)
    #
    #   # Find all records for Keith Morrison
    #   table.find :all, :first_name => "Keith", :last_name => "Morrison"
    #
    #   # Find first record
    #   table.find :first, :first_name => "Keith"
    #
    # The <b>command</b> may be a record idx, :all, or :first.
    # <b>options</b> is optional and, if specified, should be a hash where the keys correspond
    # to column names in the database.  The values will be matched exactly with the value
    # in the database.  If you specify more than one key, all values must match in order
    # for the record to be returned.  The equivalent SQL would be "WHERE key1 = 'value1'
    # AND key2 = 'value2'".
    #
    # @param [Fixnum, Symbol] command
    # @param [optional, Hash] options Hash of search parameters
    # @yield [optional, DBF::Record, NilClass]
    def find(command, options = {}, &block)
      case command
      when Fixnum
        record(command)
      when Array
        command.map {|i| record(i)}
      when :all
        find_all(options, &block)
      when :first
        find_first(options)
      end
    end

    # Retrieves column information from the database
    def columns
      @columns ||= begin
        @data.seek(DBF_HEADER_SIZE)
        columns = []
        while !["\0", "\r"].include?(first_byte = @data.read(1))
          column_data = first_byte + @data.read(31)
          name, type, length, decimal = column_data.unpack('a10 x a x4 C2')
          if length > 0
            columns << column_class.new(name.strip, type, length, decimal, version, @encoding)
          end
        end
        columns
      end
    end

    def supports_encoding?
      String.new.respond_to? :encoding
    end

    def foxpro?
      FOXPRO_VERSIONS.keys.include? @version
    end

    private

    def column_class #nodoc
      @column_class ||= if foxpro?
        Column::Foxpro
      else
        Column::Dbase
      end
    end

    def memo_class #nodoc
      @memo_class ||= if foxpro?
        Memo::Foxpro
      else
        if @version == "83"
          Memo::Dbase3
        else
          Memo::Dbase4
        end
      end
    end

    def column_count #nodoc
      @column_count ||= ((@header_length - DBF_HEADER_SIZE + 1) / DBF_HEADER_SIZE).to_i
    end

    def open_data(data) #nodoc
      data.is_a?(StringIO) ? data : File.open(data, 'rb')
    end

    def open_memo(data, memo = nil) #nodoc
      if memo.is_a? StringIO
        memo_class.new(memo, version)
      elsif memo
        memo_class.open(memo, version)
      elsif !data.is_a? StringIO
        dirname = File.dirname(data)
        basename = File.basename(data, '.*')
        files = Dir.glob("#{dirname}/#{basename}*.{fpt,FPT,dbt,DBT}")
        files.any? ? memo_class.open(files.first, version) : nil
      else
        nil
      end
    end

    def find_all(options) #nodoc
      map do |record|
        if record && record.match?(options)
          yield record if block_given?
          record
        end
      end.compact
    end

    def find_first(options) #nodoc
      index_unikey = array_to_unikey(options.keys)
      record_index = @indexes[index_unikey]
      if record_index
        fill_index(index_unikey) if record_index.empty?
        # look it up in the index
        record_index[hash_to_unikey(options)]
      else
        # walk through each record
        detect {|record| record && record.match?(options)}
      end
    end

    def fill_index(index_unikey)
      each do |record|
        next unless record
        add_to_index(index_unikey, record)
      end
    end

    def add_to_index(index_unikey, record)
      record_index = @indexes[index_unikey]
      unikey = record_to_unikey(index_unikey, record)
      if record_index.has_key?(unikey)
        raise NotYetImplementedError, "index currently only implemented for unique keys (index: #{record_index}, keyval: #{unikey}"
      end
      record_index[unikey] = record
    end

    def array_to_unikey(array)
      array.map{|k|k.to_s.downcase}.sort.join("\n")
    end

    def hash_to_unikey(hash)
      downcase_hash = Hash[*hash.map{|k,v| [k.to_s.downcase, v] }.flatten]
      record_to_unikey(array_to_unikey(hash.keys), downcase_hash)
    end

    def record_to_unikey(key_names, record)
      key_names = key_names.split unless key_names.respond_to?(:map)
      key_names.map { |name| record[name.strip.downcase] }.join("\n")
    end

    def record_active?(idx) #nodoc
      seek(idx * @record_length)
      if @data.read(1).unpack('a') == ['*'] # deletion marker
        nil
      else
        if block_given?
          yield @data.read(@record_length)
        else
          true
        end
      end
    end

#    def deleted_record?(idx) #nodoc
#      seek(idx * @record_length)
#      @data.read(1).unpack('a') == ['*']
#    end

    def get_header_info #nodoc
      @data.rewind
      @version, @total_record_count, @header_length, @record_length, @encoding_key = read_header
      @encoding = ENCODINGS[@encoding_key] if supports_encoding?
    end

    def read_header #nodoc
      if @data.eof?
        raise InvalidHeader, "Missing table header"
      end
      begin
        @data.read(DBF_HEADER_SIZE).unpack("H2 x3 V v2 x17H2")
      rescue
        raise InvalidHeader, "Cannot read table header. Message: " + $!.message
      end
    end

    def seek(offset) #nodoc
      @data.seek @header_length + offset
    end

    def csv_class #nodoc
      @csv_class ||= CSV.const_defined?(:Reader) ? FCSV : CSV
    end
  end

end
