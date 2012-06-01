# To change this template, choose Tools | Templates
# and open the template in the editor.

require File.expand_path('../../../lib/dbf/writer', __FILE__)


module DBF
  describe Writer do
    before(:each) do
      @writer = Writer.new
    end

    it "should desc" do
        fields = [
          {:field_name=>'LOCID', :field_size=>11, :field_type=>'N', :decimals=>0},
          {:field_name=>'LOCNAME', :field_size=>40, :field_type=>'C', :decimals=>0},
          {:field_name=>'LOCADDR', :field_size=>20, :field_type=>'C', :decimals=>0},
          {:field_name=>'LOCCITY', :field_size=>20, :field_type=>'C', :decimals=>0},
          {:field_name=>'LOCSTATE', :field_size=>20, :field_type=>'C', :decimals=>0},
          {:field_name=>'LOCZIP', :field_size=>20, :field_type=>'C', :decimals=>0}
        ]
 
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
 
        file_name = "#{File.dirname(File.dirname(__FILE__))}/tmp/proba.dbf"
        File.delete(file_name)
        dbf_writer(file_name, fields, records)
        File.exist?(file_name).should be_true
 
      # TODO
    end
  end
end
