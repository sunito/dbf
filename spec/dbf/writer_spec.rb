# To change this template, choose Tools | Templates
# and open the template in the editor.

require File.expand_path('../../../lib/dbf/writer', __FILE__)

module DBF
  describe WriTable do
    before(:all) do
      @dbf_file_name = "#{File.dirname(File.dirname(__FILE__))}/tmp/proba.dbf"      
    end
    before(:each) do
      File.delete(@dbf_file_name) if File.exist?(@dbf_file_name)

      @fields = [
        {:field_name=>'LOCID', :field_size=>11, :field_type=>'N', :decimals=>0},
        {:field_name=>'LOCNAME', :field_size=>40, :field_type=>'C', :decimals=>0},
        {:field_name=>'LOCADDR', :field_size=>20, :field_type=>'C', :decimals=>0},
        {:field_name=>'LOCCITY', :field_size=>20, :field_type=>'C', :decimals=>0},
        {:field_name=>'LOCSTATE', :field_size=>20, :field_type=>'C', :decimals=>0},
        {:field_name=>'LOCZIP', :field_size=>20, :field_type=>'C', :decimals=>0}
      ]
      
      @writer = WriTable.new(@dbf_file_name, @fields)
    end

    it "should work" do
 
      records = [
        {:LOCID=>1,
          :LOCNAME=>'My Place', #ÁRVÍZTŰRŐ TÜKÖRFÚRÓGÉP árvíztűrő tükörfúrógép',
          :LOCADDR=>'LOCADDR1',
          :LOCCITY=>'LOCCITY1',
          :LOCSTATE=>'LOCSTATE1',
          :LOCZIP=>'LOCZIP1'},
        {:LOCID=>2,
          :LOCNAME=>'LOCNAME2',
          :LOCADDR=>'LOCADDR2',
          :LOCCITY=>'LOCCITY2',
          :LOCSTATE=>'LOCSTATE2',
          :LOCZIP=>'LOCZIP2'},
        {:LOCID=>3,
          :LOCNAME=>'LOCNAME3',
          :LOCADDR=>'LOCADDR3',
          :LOCCITY=>'LOCCITY3',
          :LOCSTATE=>'LOCSTATE3',
          :LOCZIP=>'LOCZIP3'}
      ]
 
      @writer.write(records)

      File.read(@dbf_file_name).should == File.read("#{File.dirname(File.dirname(__FILE__))}/fixtures/writer/simple1_6fields3records.dbf")
    end
  end
end
