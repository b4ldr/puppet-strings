# frozen_string_literal: true

require 'spec_helper'
require 'puppet-strings/yard'

describe PuppetStrings::Yard::Handlers::Ruby::TypeExtrasHandler do
  subject {
    YARD::Parser::SourceParser.parse_string(source, :ruby)
    YARD::Registry.all(:puppet_type)
  }

  describe 'parsing source with newproperty' do
    let(:source) { <<~SOURCE
      Puppet::Type.newtype(:database) do
        desc 'database'
      end
      Puppet::Type.type(:database).newproperty(:file) do
        desc 'The database file to use.'
      end
    SOURCE
    }

    it 'generates a doc string for a property' do
      expect(subject.size).to eq(1)
      object = subject.first
      expect(object.properties.size).to eq(1)
      expect(object.properties[0].name).to eq('file')
      expect(object.properties[0].docstring).to eq('The database file to use.')
    end
  end

  describe 'parsing source with newparam' do
    let(:source) { <<~SOURCE
      Puppet::Type.newtype(:database) do
        desc 'database'
      end
      Puppet::Type.type(:database).newparam(:name) do
        desc 'The database server name.'
      end
    SOURCE
    }

    it 'generates a doc string for a parameter that is also a namevar' do
      expect(subject.size).to eq(1)
      object = subject.first
      expect(object.parameters.size).to eq(1)
      expect(object.parameters[0].name).to eq('name')
      expect(object.parameters[0].docstring).to eq('The database server name.')
      expect(object.parameters[0].isnamevar).to eq(true)
    end
  end
end
