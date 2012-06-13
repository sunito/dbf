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
  class WriTable < Table
    class InitError < StandardError; end
    class MissingStructureError < StandardError; end
    
    def initialize(file_name_or_stringio, column_defs = nil)
      # if file_name_or_stringio
      
      @data = init_data(file_name_or_stringio)
      
      if @initial_data_present
        get_header_info 
      else
        @version = "03"
        @total_record_count = 0
      end
      @column_defs = column_defs
            
    end
    
    def init_data(file_name_or_stringio)      
      if file_name_or_stringio.is_a?(StringIO) 
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
    end
    
    def has_structure?
      !!(@column_defs || @header_length)
    end
    
    def write(records, column_defs = nil)

      store_column_defs(column_defs)
      @record_count = records.size
      write_header
      
      records.each_with_index do |record, idx|
        next unless record
        
        seek(idx * @record_length)
        
        @data.write(' ')

        @columns.each do |c|
          value = record[c.name.to_sym]

          if c.type == 'N'
            value = Iconv.conv('CP1250', 'UTF-8', value.to_s.rjust(c.length, ' '))
          else
            value = Iconv.conv('CP1250', 'UTF-8', value.to_s[0,c.length].ljust(c.length, ' '))
          end


          if value.length != c.length
            raise "Record too long"
          end

          # Write value
          @data.write(value)

        end # fields.each
      end
      finish
    end
    
    def close
      @data.close
    end

    def column_defs=(cdefs)
      if cdefs
        store_column_defs cdefs
      end
      @column_defs = cdefs
    end
    
    def save
      write(@records)
      @saved = true
    end
    
    # now cached
    def record(idx)
      @records ||= []
      @records[idx] ||= super
    end
    
  private    
    def store_column_defs(column_defs = nil)
      column_defs ||= @column_defs 
      @columns = if column_defs.nil?
        if @initial_data_present
          columns        
        else
          raise MissingStructureError, "Cannot write without any column definition"
        end
        # Todo: raise better error  if no columns
      else
        column_defs.map do |c| 
          if c.is_a? Column::Base
            c.dup
          else
            column_class.new(c[:field_name], c[:field_type], c[:field_size], c[:decimals], 3)
          end
        end
      end
      @column_count = @columns.size
    end
    

    
    
    def write_header  #(record_count)
      @version = 3

      fixed_header_size = 32
      @header_length = DBF_HEADER_SIZE + @column_count * 32 + 1     # The length of the header
      @record_length = 1 + @columns.sum(&:length)
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
      header << @header_length
      header << @record_length                           # The length of each record

      hdr = header.pack('CCCCVvvxxxxxxxxxxxxxxxxxxxx')

      @data.rewind
      # Write out the header
      @data.write(hdr)

      @columns.each do |c|                                  
        field = Array.new
        field << c.original_name.ljust(11, "\x00")
        field << c.type[0]
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
		