# Encoding: UTF-8

require 'spec_helper'

describe Parslet::Source do
  describe "using simple input" do
    let(:io) { StringIO.new("a"*100 + "\n" + "a"*100 + "\n") }
    let(:source) { described_class.new(io) }

    describe "<- #initialize" do
      it "should turn a string into an IO" do
        source = described_class.new("foo")
        source.read(1).to_s.should == 'f'
      end
    end
    describe "<- #read(n)" do
      it "should not raise error when the return value is nil" do
        described_class.new('').read(1)
      end 
      it "should return 100 'a's when reading 100 chars" do
        source.read(100).should == 'a'*100
      end
      it "should raise ArgumentError when reading <= 1 chars" do
        expect {
          source.read(0)
        }.to raise_error(ArgumentError)
      end 
    end
    describe "<- #eof?" do
      subject { source.eof? }

      it { should be_false }
      context "after depleting the source" do
        before(:each) { source.read(10000) }

        it { should be_true }
      end
    end
    describe "<- #pos" do
      subject { source.pos }

      it { should == 0 }
      context "after reading a few bytes" do
        it "should still be correct" do
          pos = 0
          10.times do
            pos += (n = rand(10)+1)
            source.read(n)

            source.pos.should == pos
          end
        end 
      end
    end
    describe "<- #pos=(n)" do
      subject { source.pos }
      10.times do
        pos = rand(200)
        context "setting position #{pos}" do
          before(:each) { source.pos = pos }

          it { should == pos }
        end
      end
    end
    describe "<- #column & #line" do
      subject { source.line_and_column }

      it { should == [1,1] }

      context "on the first line" do
        it "should increase column with every read" do
          10.times do |i|
            source.line_and_column.last.should == 1+i
            source.read(1)
          end
        end 
      end
      context "on the second line" do
        before(:each) { source.read(101) }
        it { should == [2, 1]}
      end
      context "after reading everything" do
        before(:each) { source.read(10000) }

        context "when seeking to 9" do
          before(:each) { source.pos = 9 }
          it { should == [1, 10] }
        end
        context "when seeking to 100" do
          before(:each) { source.pos = 100 }
          it { should == [1, 101] }
        end
        context "when seeking to 101" do
          before(:each) { source.pos = 101 }
          it { should == [2, 1] }
        end
        context "when seeking to 102" do
          before(:each) { source.pos = 102 }
          it { should == [2, 2] }
        end
        context "when seeking beyond eof" do
          it "should not throw an error" do
            source.pos = 1000
          end 
        end
      end
      context "reading char by char, storing the results" do
        attr_reader :results
        before(:each) { 
          @results = {}
          while not source.eof?
            pos = source.pos
            @results[pos] = source.line_and_column
            source.read(1)
          end

          @results.should have(202).entries
          @results
        }

        context "when using pos argument" do
          it "should return the same results" do
            results.each do |pos, result|
              source.line_and_column(pos).should == result
            end
          end 
        end
        it "should give the same results when seeking" do
          results.each do |pos, result|
            source.pos = pos
            source.line_and_column.should == result
          end
        end
        it "should give the same results when reading" do
          cur = source.pos = 0
          while not source.eof?
            source.line_and_column.should == results[cur]
            cur += 1
            source.read(1)
          end
        end 
      end
    end
    
  end

  describe "reading encoded input", :ruby => 1.9 do
    let(:source) { described_class.new("éö変わる") }
    
    it "should read characters, not bytes" do
      source.read(1).should == "é"
      source.read(1).should == "ö"
      source.read(1).should == "変"
    end 
  end
end
