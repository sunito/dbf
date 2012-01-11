module DBF
  module Binary
    class FieldDescriptor < BinData::Record
      endian :little
        
      string :name, :length => 11
      string :data_type, :length => 1
      skip :length => 4
      uint8 :data_length
      uint8 :decimal
      skip :length => 14
      
      def clean_name
        name.value.strip
      end
    end
  end
end