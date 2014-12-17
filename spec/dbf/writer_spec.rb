# To change this template, choose Tools | Templates
# and open the template in the editor.

require File.expand_path('../../../lib/dbf', __FILE__)
require File.expand_path('../../../lib/dbf/writer', __FILE__)

module DBF
  describe WriTable do
    before(:all) do
      @dbf_file_name = "#{File.dirname(File.dirname(__FILE__))}/tmp/proba.dbf"
      @dbf2_file_name = "#{File.dirname(File.dirname(__FILE__))}/tmp/probb.dbf"
      @fixt_dbf_simple1_fn = "#{File.dirname(File.dirname(__FILE__))}/fixtures/writer/simple1_6fields3records.dbf"
      @fixt_dbf_simple1_content = File.read(@fixt_dbf_simple1_fn)
      t = Time.now
      @fixt_dbf_simple1_content[1,3] = [t.year-1900, t.month, t.day].pack("CCC")
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
      @records.each do |rec|
        class << rec
          alias old_access :[]
          def [](key)
            old_access(key.to_s.upcase.to_sym)
          end
        end
      end

    end

    it "should know about its missing structure non-existing file" do
      @writer = WriTable.new(@dbf_file_name)
      @writer.has_structure?.should be_false

      expect {@writer.write(@records)}.to raise_error WriTable::MissingStructureError
      @writer.close

      File.read(@dbf_file_name).should == ""
    end

    it "should create a non-existing dbf-file" do
      @writer = WriTable.new(@dbf_file_name, @fields)
      @writer.has_structure?.should be_true

      @records.each do |r|
        @writer.add_record(Hash[*r.map{|k,v| [k.to_s.downcase,v]}.flatten])
      end
      @writer.close

      File.read(@dbf_file_name).should == @fixt_dbf_simple1_content
    end

    it "should not produce errors with a non-existing file" do
      @writer = WriTable.new(@dbf_file_name, @fields)
      @writer.has_structure?.should be_true

      @writer.find(:first, :LOCNAME=>'Blabla').should be_nil
      @writer.close
    end

    it "should be able to read columns from an existing file" do
      FileUtils.copy @fixt_dbf_simple1_fn, @dbf_file_name

      @writer = WriTable.new(@dbf_file_name)
      @writer.has_structure?.should be_true
      @writer.write(@records)
      @writer.close

      File.read(@dbf_file_name).should == @fixt_dbf_simple1_content
    end

    it "should write the same values that it has read" do
      FileUtils.copy @fixt_dbf_simple1_fn, @dbf_file_name

      @writer = WriTable.new(@dbf_file_name)
      recs = @writer.find(:all)
      @writer.write(recs)
      @writer.close

      File.read(@dbf_file_name).should == @fixt_dbf_simple1_content
    end

    it "should copy the same values that it has read" do
      File.delete(@dbf2_file_name) if File.exist?(@dbf2_file_name)

      FileUtils.copy @fixt_dbf_simple1_fn, @dbf_file_name

      @source = WriTable.new(@dbf_file_name)
      recs = @source.find(:all)

      @writer = WriTable.new(@dbf2_file_name)
      @writer.column_defs = @source.columns
      recs.each do |rec|
        @writer.add_record(rec)
      end
      @writer.save
      @writer.close

      @source.close

      File.read(@dbf2_file_name).should == @fixt_dbf_simple1_content
    end

    it "should correctly write modified records" do
      FileUtils.copy @fixt_dbf_simple1_fn, @dbf_file_name

      @writer = WriTable.new(@dbf_file_name)
      recs = @writer.find(:all)
      recs[0].attributes["locid"] = 44
      @writer.write(recs)
      @writer.close

      File.read(@dbf_file_name).should == @fixt_dbf_simple1_content.sub(" 1My Place", "44My Place")
    end

  end
end
