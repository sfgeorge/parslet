require 'spec_helper'

describe 'VM operation' do
  extend Parslet
  include Parslet
  
  def self.rule(name, &block)
    let(name) { example = self; Parslet::Atoms::Entity.new(name) { 
      example.instance_eval(&block) } }
  end
  
  # Compiles the parser and runs it through the VM with the given input. 
  #
  def vm_parse(parser, input)
    compiler = Parslet::Bytecode::Compiler.new
    program = compiler.compile(parser)
    
    vm = Parslet::Bytecode::VM.new(false)
    vm.run(program, input)
  end
  
  # Checks if the VM code parses input the same as if you did
  # parser.parse(input).
  def vm_parses(parser, input)
    result = parser.dup.parse(input)
    
    vm_result = vm_parse(parser, input)
    
    vm_result.should == result
  end
  
  # Checks if the VM correctly fails on applying parser to input. 
  #
  def vm_fails(parser, input)
    orig_parser = parser.dup
    exception = catch_exception {
      orig_parser.parse(input)
    }

    vm_exception = catch_exception {
      vm_parse(parser, input)
    }
    
    vm_exception.should_not be_nil
    vm_exception.message.should == exception.message
    vm_exception.class.should == exception.class
    
    vm_exception.cause.ascii_tree.should == orig_parser.error_tree.to_s
  end
  
  describe 'comparison parsing: ' do
    describe 'strings' do
      it "parses" do
        vm_parses str('foo'), 'foo'
      end
      it "error out" do
        vm_fails str('foo'), 'bar'
      end 
    end
    describe 'match' do
      it "parses" do
        vm_parses match['foo'], 'f'
      end 
      it "errors out (mismatch)" do
        vm_fails match['foo'], 'b'
      end  
    end
    describe 'sequences' do
      it "should parse" do
        vm_parses str('f') >> str('oo'), 'foo'
      end
      it "should error out with the correct message" do
        vm_fails str('f') >> str('b'), 'fa'
      end 
      it "errors out on EOF" do
        vm_fails str('f')>>str('b'), ''
      end 
    end
    describe 'alternatives' do
      it "parses left side" do
        vm_parses str('f') | str('o'), 'f'
      end
      it "parses right side" do
        vm_parses str('f') | str('o'), 'o'
      end
      it "errors out" do
        vm_fails str('f') | str('o'), 'b'
      end 
    end
    describe 'repetition' do
      it "parses" do
        vm_parses str('a').repeat, 'aaa'
      end 
      it "errors out (minimal repetition)" do
        vm_fails str('a').repeat(1), ''
      end 
    end
    describe 'named' do
      it "parses" do
        vm_parses str('foo').as(:bar), 'foo'
      end 
    end
    describe 'positive lookahead' do
      it "parses" do
        vm_parses str('foo').present? >> str('foo'), 'foo'
      end 
      it "errors out correctly" do
        vm_fails str('foo').present? >> str('foo'), 'bar'
      end 
    end
    describe 'negative lookahead' do
      it "parses" do
        vm_parses str('f').absent? >> str('o'), 'o'
      end 
      it "errors out" do
        vm_fails str('f').absent? >> str('o'), 'f'
      end 
    end
    describe 'entities' do
      it "should parse" do
        atom = Parslet::Atoms::Entity.new('foo') { str('foo') }
        vm_parses atom, 'foo'
      end
      it "errors out properly" do
        atom = Parslet::Atoms::Entity.new('foo') { str('foo') }
        vm_fails atom, 'bar'
      end 
    end
    describe 'error handling' do
      it "errors out when source is not read completely" do
        vm_fails str('fo'), 'foo'
      end
      it "generates the correct error tree for simple string mismatch" do
        vm_fails str('foo'), 'bar'
      end 
    end
    describe 'a Parslet::Parser' do
      let(:parser) {
        Class.new(Parslet::Parser) do
          root(:foobar)
          rule(:foobar) {
            str('foo') >> str('bar')
          }
        end
      }
      
      it "parses" do
        vm_parses parser.new, 'foobar'
      end 
    end
  end
  
  describe 'places where the classic version is different' do
    context 'that weird unconsumed message' do
      it "also responds with an error, perhaps a more simple one" do
        ex = catch_exception {
          vm_parse str('a').repeat(1), 'a.'
        }
        ex.should be_kind_of(Parslet::UnconsumedInput)
        ex.message.should == "Don't know what to do with . at line 1 char 2."
      end 
    end
    
    describe 'match' do
      it "errors out (premature end of input)" do
        catch_exception { 
          vm_parse match['foo'].repeat(1), ''
        }.cause.ascii_tree.should == \
          "`- Expected at least 1 of [foo] at line 1 char 1.\n   `- Premature end of input at line 1 char 1.\n"
      end
    end
  end

  describe 'regressions' do
    describe 'repetitions' do
      let(:simple) { str('a') >> str('b') }
      let(:comp)   { simple.repeat(1) }
      it "should reset source pos correctly" do
        catch_exception { vm_parse comp, 'aba' }.
          cause.ascii_tree.should == "`- Don't know what to do with a at line 1 char 3.\n"
      end 
    end
    describe 'alternatives' do
      rule(:radix) { digit >> str('r') >> digit }
      rule(:digit) { match['\d'].repeat(1) }
      rule(:atom) { radix | digit }
      it "should correctly reset source pos" do
        vm_parses atom, '5'
      end 
    end
    describe 'the common space? idiom' do
      let(:space_p) { match['\s'].repeat(1).maybe }
      
      it "parses space" do
        vm_parses space_p, "    \t   "
      end 
      it "parses nothing" do
        vm_parses space_p, ""
      end 
      it "stops parsing at the first char" do
        vm_parses space_p >> str('a'), '   a'
      end 
    end
    describe 'stack state after long alternatives (from http parser)' do
      let(:pchar) {
        str(':') | str('@') | str('&') | str('=') | str('+') }
      let(:path) { pchar.repeat(1) >> (str('/') >> pchar.repeat).repeat }
      
      it "fails to match path correctly" do
        vm_parses path, '@'
      end 
    end
  end
end