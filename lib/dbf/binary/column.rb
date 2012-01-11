module DBF
  module Binary
    class Column < BinData::Record
      endian :little
        
      string :name, :length => 10
      skip :length => 1
      string :data_type, :length => 1
      skip :length => 4
      uint8 :data_length
      uint8 :decimal
  
      def length
        field_names.inject(1) {|s,n| s += n.size}
      end
    end
  end
end