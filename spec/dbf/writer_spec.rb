# To change this template, choose Tools | Templates
# and open the template in the editor.

require File.expand_path('../../../lib/dbf/writer', __FILE__)

module DBF
  describe WriTable do
    before(:all) do
      @dbf_file_name = "#{File.dirname(File.dirname(__FILE__))}/tmp/proba.dbf"      
      @fixt_dbf_fn_simple1 = "#{File.dirname(File.dirname(__FILE__))}/fixtures/writer/simple1_6fields3records.dbf"
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
      
      @records = [
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
 
    end

    it "should create a non-existing file" do
      @writer = WriTable.new(@dbf_file_name, @fields)
 
      @writer.write(@records)
      @writer.close

      File.read(@dbf_file_name).should == File.read(@fixt_dbf_fn_simple1)
    end
      
    it "should be able to read columns from an existing file" do
      FileUtils.copy @fixt_dbf_fn_simple1, @dbf_file_name
      
      @writer = WriTable.new(@dbf_file_name)
      @writer.write(@records)
      @writer.close

      File.read(@dbf_file_name).should == File.read(@fixt_dbf_fn_simple1)
    end

    it "should write the same values that it has read" do
      FileUtils.copy @fixt_dbf_fn_simple1, @dbf_file_name
      
      @writer = WriTable.new(@dbf_file_name)
      recs = @writer.find(:all)
      @writer.write(recs)
      @writer.close

      File.read(@dbf_file_name).should == File.read(@fixt_dbf_fn_simple1)
    end

    it "should correctly write modified records" do
      FileUtils.copy @fixt_dbf_fn_simple1, @dbf_file_name
      
      @writer = WriTable.new(@dbf_file_name)
      recs = @writer.find(:all)
      recs[0].attributes["LOCID"] = 44
      @writer.write(recs)
      @writer.close

      File.read(@dbf_file_name).should == File.read(@fixt_dbf_fn_simple1).sub(" 1My Place", "44My Place")
    end

  end
end
