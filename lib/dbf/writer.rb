# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'iconv'

#require File.expand_path('../table', __FILE__)
#require File.expand_path('../column/base', __FILE__)
#require File.expand_path('../column/dbase', __FILE__)
#require File.expand_path('../record', __FILE__)

if not Array.instance_methods.map{|x|x.to_s}.include?("sum")
  class Array
    def sum
      slice(1..-1).inject(yield(first)) do |s, value|
        s + yield(value)
      end
    end
  end

end


module DBF

  # monkeypatching, sorry...
  class Record
    def method_missing(method, *args)
      method_name = method.to_s
      if index = column_names.index(method_name)
        attributes[@columns[index].underscored_name]
      elsif  method_name =~ /=$/ and index = column_names.index(method_name.chop)
        attributes[@columns[index].underscored_name] = args.first
      else
        super
      end
    end
  end

  class WriTable < Table
    class InitError < StandardError; end
    class MissingStructureError < StandardError; end

    def initialize(file_name_or_stringio, column_defs = nil)
      # if file_name_or_stringio

      init_data(file_name_or_stringio)

      if @initial_data_present
        get_header_info
      else
        @version = "03"
        @total_record_count = 0
      end
      @column_defs = column_defs

      @indexes = {}
      @records = []
    end

    def init_data(file_name_or_stringio)
      @data = if file_name_or_stringio.is_a?(StringIO)
        @initial_data_present = true
        file_name_or_stringio
      elsif File.exist?(file_name_or_stringio)
        @initial_data_present = true
        # open_data(file_name_or_stringio)
        File.open(file_name_or_stringio, 'r+b')
      else
        @initial_data_present = false
        raise "File name expected, got #{file_name_or_stringio.inspect}" unless file_name_or_stringio.respond_to?(:upcase)
        File.open(file_name_or_stringio, "w+b")
      end
      @initial_data_present = false if @data.eof?
    end

    def has_file?
      !!(@initial_data_present || @has_been_written)
    end

    def has_structure?
      !!(@column_defs || @initial_data_present)
    end

    # writes only records that are
    

    def write(records, column_defs = nil)

      self.column_defs = column_defs if column_defs

      @record_count = records.size
      write_header

      records.each_with_index do |record, idx|
        next unless record

        seek(idx * record_length)

        @data.write(' ')

        columns.each do |c|
          value = record[c.name.to_sym]

          if c.type == 'N'
            value = value.to_s.rjust(c.length, ' ')
          else
            value = value.to_s[0,c.length].ljust(c.length, ' ')
          end
          value = Iconv.new('CP1250', 'UTF-8').iconv(value)

          if value.length != c.length
            raise "Record too long"
          end

          # Write value
          @data.write(value)

        end # fields.each
      end
      finish
      @deleted_record_count = nil # could be optimized
      @has_been_written = true
    end

    def close
      save if has_structure?
      @data.close && @data.closed?
    end

    def column_defs= cdefs
      if cdefs != @column_defs or cdefs.nil?
        @column_defs = cdefs
        @columns = nil   # invalidate columns cache
      end
    end

    def save
      write( (0...@total_record_count).map {|i| record(i)} )
      @data.flush
      @saved = true
    end

    def add_record(attributes={})
      attributes = attributes.attributes if attributes.respond_to?:attributes
      new_rec = (@record_class||Record).new("", columns, version, false)
      @records[@total_record_count] = new_rec
      new_rec.instance_variable_set( :@attributes, attributes.dup)
      @indexes.keys.each do |index_unikey|
        add_to_index(index_unikey, new_rec)
      end
      @total_record_count += 1
      @saved = false
      new_rec
    end

    # now cached
    def record(idx)
      @records[idx] ||= super
    end

    def columns
      @columns = if @column_defs.nil?
        if @initial_data_present
          super
        else
          source_info = ("file name: #{@data.path}" rescue "from string")
          raise MissingStructureError, "Column information needed (#{source_info})"
        end
        # Todo: raise better error  if no columns
      else
        @column_defs.map do |c|
          if c.is_a? Column::Base
            c.dup
          else
            column_class.new(c[:field_name], c[:field_type], c[:field_size], c[:decimals], 3)
          end
        end
      end
      @columns
    end

    def column_count
      @columns.size
    end

    def deleted_record_count
      if has_file?
        super
      else
        0
      end
    end

  protected
    def record_length
      @record_length ||= 1 + columns.sum{|c|c.length}
    end

    # The length of the dbf file header
    def header_length
      @header_length ||= DBF_HEADER_SIZE + columns.size * 32 + 1
    end

  private

    def write_header  #(record_count)
      @version = 3

      fixed_header_size = 32
      
      #@encoding_key
      #@encoding = ENCODINGS[@encoding_key] if supports_encoding?

      now = Time.now()

      # Header Info
      header = Array.new
      header << @version                                         # Version
      header << now.year-1900                             # Year
      header << now.month                                 # Month
      header << now.day                                   # Day
      header << @record_count                            # Number of records
      header << header_length
      header << record_length                           # The length of each record

      hdr = header.pack('CCCCVvvxxxxxxxxxxxxxxxxxxxx')

      @data.rewind
      # Write out the header
      @data.write(hdr)

      columns.each do |c|
        field = Array.new
        field << c.original_name.ljust(11, "\x00")
        field << c.type[0,1].ord
        field << c.length
        field << c.decimal
        fld = field.pack('a11cxxxxCCxxxxxxxxxxxxxx')

        # Write out field descriptor
        @data.write(fld)
      end

      # Write terminator '\r'
      @data.write("\r")
    end # write_header

    def finish
      # Write end of file '\x1A'
      @data.write("\x1A")

#      File.open(@file_name, 'w') do |f|
#        f.write(@data.string)
#      end
    end

  end
end

# Snippet from http://rubyforge.org/snippet/detail.php?type=snippet&id=253
#
#Joe Lobraco
#Latest Snippet Version: :0.1
#id=330	v0.1	2008-01-09 05:22	Joe Lobraco

# A ruby function that can write a basic dbf file.
#
# Currently this function only handles text and number fields.
#
# This function takes a filename, a field structure array, and a record array
# as parameters.
#
# The field structure array is a list of hashes that contain the following:
#   :field_name - the name of the field (10 characters max)
#   :field_size - the length of the field (for number fields must be long
#                 enough to hold the string representation of the number)
#   :field_type - 'N' for number fields (max 18 character length)
#                 'C' for string fields (max 254 character length)
#   :decimals   - The number of decimal places for number fields
#                 (0 for integers and other data types)
#
#  Example:
#
#  fields = [
#    {:field_name=>'LOCID', :field_size=>11, :field_type=>'N', :decimals=>0},
#    {:field_name=>'LOCNAME', :field_size=>254, :field_type=>'C', :decimals=>0},
#    {:field_name=>'LOCADDR', :field_size=>100, :field_type=>'C', :decimals=>0},
#    {:field_name=>'LOCCITY', :field_size=>40, :field_type=>'C', :decimals=>0},
#    {:field_name=>'LOCSTATE', :field_size=>2, :field_type=>'C', :decimals=>0},
#    {:field_name=>'LOCZIP', :field_size=>5, :field_type=>'C', :decimals=>0}
#  ]
#
#  The record structure array is a list of hashes that contain the data, hashed by
#  the field name.
#
#  Example:
#
#  records = [
#   {:LOCID=>1, :LOCNAME=>'My Place', :LOCADDR=>'123 Main St.',
#    :LOCCITY=>'Austin', :LOCSTATE=>'TX', :LOCZIP=>'55555'},
#   {:LOCID=>2, :LOCNAME=>'Your Place', :LOCADDR=>'12 Smith Ave.',
#    :LOCCITY=>'New York', :LOCSTATE=>'NY', :LOCZIP=>'12345'},
#   {:LOCID=>3, :LOCNAME=>'Their Place', :LOCADDR=>'100 N. High Blvd',
#    :LOCCITY=>'Atlanta', :LOCSTATE=>'GA', :LOCZIP=>'54321'}
#  ]
#
# ACKNOWLEDGMENTS:
#
# This code was modeled after the Python DBF Reader and Writer script
# written by Raymond Hettinger found on the ASPN website:
# http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/362715
#
# Additionally, information on the dbf file format that was used in
# creating this function was found on this website:
# http://www.clicketyclick.dk/databases/xbase/format/dbf.html
#

