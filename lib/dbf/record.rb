module DBF
  # An instance of DBF::Record represents a row in the DBF file 
  class Record
    # Initialize a new DBF::Record
    # 
    # @data [String, StringIO] data
    # @columns [Column]
    # @version [String]
    # @memo [DBF::Memo]
    def initialize(data, columns, version, memo)
      @data = StringIO.new(data)
      @columns, @version, @memo = columns, version, memo
    end
    
    # Equality
    #
    # @param [DBF::Record] other
    # @return [Boolean]
    def ==(other)
      other.respond_to?(:attributes) && other.attributes == attributes
    end
    
    # Maps a row to an array of values
    # 
    # @return [Array]
    def to_a
      @columns.map {|column| attributes[column.underscored_name]}
    end
    
    # Do all search parameters match?
    #
    # @param [Hash] options
    # @return [Boolean]
    def match?(options)
      options.all? {|key, value| self[key] == value}
    end

    # Reads attributes by column name
    def [](key)
      key = key.to_s
      if attributes.has_key?(key)
        attributes[key]
      elsif index = original_column_names.index(key)
        attributes[@columns[index].underscored_name]
      end
    end
    
    # @return [Hash]
    def attributes
      @attributes ||= begin
        @data.rewind
        ha = @columns.map {|column| [column.underscored_name, init_attribute(column)]}
        Hash[*ha.flatten]
      end
    end
    
    def respond_to?(method, *args)
      return true if column_names.include?(method.to_s)
      super
    end

    def method_missing(method, *args)
      if index = column_names.index(method.to_s)
        attributes[@columns[index].underscored_name]
      else
        super
      end
    end

    private

    def column_names
      @column_names ||= @columns.map {|column| column.underscored_name}
    end
    
    def original_column_names
      @original_column_names ||= @columns.map {|column| column.name}
    end
    
    def init_attribute(column) #nodoc
      value = if column.memo?
        @memo.get get_memo_start_block(column)
      else
        unpack_data(column)
      end
      column.type_cast value
    end
   
    def get_memo_start_block(column) #nodoc
      if %w(30 31).include?(@version)
        @data.read(column.length).unpack('V').first
      else
        unpack_data(column).to_i
      end
    end

    def unpack_data(column) #nodoc
      @data.read(column.length).unpack("a#{column.length}").first
    end
    
  end
end
