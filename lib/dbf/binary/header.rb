module DBF
  module Binary
    class Header < BinData::Record
      endian :little
  
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
      uint8 :encrypted
      skip :length => 4
      skip :length => 8
      uint8 :mdx
      uint8 :language
      skip :length => 2
  
      def version_hex
        version.to_i.to_s(16).rjust(2, '0')
      end
  
      def language_hex
        language.to_i.to_s(16).rjust(2, '0')
      end
  
      def last_update
        Date.new _last_update.year, _last_update.month, _last_update.day
      end
    end
  end
end