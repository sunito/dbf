# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'iconv'

require File.expand_path('../table', __FILE__)
require File.expand_path('../column/base', __FILE__)
require File.expand_path('../column/dbase', __FILE__)

if not Array.instance_methods.map(&:to_s).include?("sum")
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
    def initialize(file_name, fields)
      @file_name = file_name
      @columns = fields.map do |f| 
        if f.is_a? Column::Dbase
          f
        else
          Column::Dbase.new(f[:field_name], f[:field_type], f[:field_size], f[:decimals], 3)
        end
      end
      @column_count = @columns.size
      @data = StringIO.new
    end
    
    def write(records)
      @record_count = records.size
      write_header
      records.each do |record|
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
    
    def write_header  #(record_count)
      @data.rewind
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

      # Write out the header
      @data.write(hdr)

      @columns.each do |c|                                  
        field = Array.new
        field << c.name.ljust(11, "\x00")
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
      
      File.open(@file_name, 'w') do |f|
        f.write(@data.string)
      end
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

def dbf_writer(filename, fields, records)

  File.open(filename, 'w') do |dbf|

    now = Time.now()
    numfields = fields.length

    # Header Info
    header = Array.new
    header << 3                                         # Version
    header << now.year-1900                             # Year
    header << now.month                                 # Month
    header << now.day                                   # Day
    header << records.length                            # Number of records
    header << (numfields * 32 + 33)                     # The length of the header
    x = 0
    fields.each { |f| x+=f[:field_size] }
    header << x + 1                                     # The length of each record

    hdr = header.pack('CCCCVvvxxxxxxxxxxxxxxxxxxxx')

    # Write out the header
    dbf.write(hdr)

    fields.each do |f|                                  
      field = Array.new
      field << f[:field_name].ljust(11, "\x00")
      field << f[:field_type][0]
      field << f[:field_size]
      field << f[:decimals]
      fld = field.pack('a11cxxxxCCxxxxxxxxxxxxxx')

      # Write out field descriptor
      dbf.write(fld)
    end

    # Write terminator '\r'
    dbf.write("\r")

    records.each do |r|
      # Write deletion flag
      dbf.write(' ')

      fields.each do |f|
        value = r[f[:field_name].to_sym]

        if f[:field_type] == 'N'
          value = Iconv.conv('CP1250', 'UTF-8', value.to_s.rjust(f[:field_size], ' '))
        else
          value = Iconv.conv('CP1250', 'UTF-8', value.to_s[0,f[:field_size]].ljust(f[:field_size], ' '))
        end


        if value.length != f[:field_size]
          raise "Record too long"
        end

        # Write value
        dbf.write(value)

      end # fields.each
    end # records.each

    # Write end of file '\x1A'
    dbf.write("\x1A")

  end # File.open
end





		