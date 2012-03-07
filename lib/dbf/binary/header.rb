module DBF
  module Binary
    class Header < BinData::Record
      endian :little
      
      # The size of the header up to (but not including) the field descriptors
      FILE_HEADER_SIZE = 32
  
      uint8 :version
      struct :_last_update do
        uint8 :year
        uint8 :month
        uint8 :day
      end
      uint32 :record_count
      uint16 :header_length
      uint16 :record_length
      skip :length => 2
      uint8 :incomplete_transaction
      uint8 :_encrypted
      skip :length => 4
      skip :length => 8
      uint8 :mdx
      uint8 :code_page
      skip :length => 2
      array :field_descriptors, :type => :field_descriptor, :read_until => lambda {
        ["\0", "\r"].include?(element.name[0]) || index == field_count - 1
      }
  
      def version_hex
        version.to_i.to_s(16).rjust(2, '0')
      end
  
      def code_page_hex
        code_page.to_i.to_s(16).rjust(2, '0')
      end
  
      def last_update
        Date.new _last_update.year, _last_update.month, _last_update.day
      end
      
      def encrypted
        !_encrypted.zero?
      end
      
      def field_count
        ((header_length - FILE_HEADER_SIZE + 1) / FILE_HEADER_SIZE).to_i
      end
    end
  end
end