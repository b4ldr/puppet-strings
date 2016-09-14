require 'puppet-strings/yard/handlers/ruby/base'
require 'puppet-strings/yard/code_objects'
require 'puppet/util/docs'

# Implements the handler for Puppet providers written in Ruby.
class PuppetStrings::Yard::Handlers::Ruby::ProviderHandler < PuppetStrings::Yard::Handlers::Ruby::Base
  namespace_only
  handles method_call(:provide)

  process do
    return unless statement.count >= 2

    # Check that provide is being called on Puppet::Type.type(<name>)
    type_call = statement[0]
    return unless type_call.is_a?(YARD::Parser::Ruby::MethodCallNode) && type_call.count >= 3
    return unless type_call[0].source == 'Puppet::Type'
    return unless type_call[2].source == 'type'

    # Extract the type name
    type_call_parameters = type_call.parameters(false)
    return unless type_call_parameters.count >= 1
    type_name = node_as_string(type_call_parameters.first)
    raise YARD::Parser::UndocumentableError, "Could not determine the resource type name for the provider defined at #{statement.file}:#{statement.line}." unless type_name

    # Register the object
    object = PuppetStrings::Yard::CodeObjects::Provider.new(type_name, get_name)
    register object

    # Extract the docstring
    register_provider_docstring object

    # Populate the provider data
    populate_provider_data object

    # Mark the provider as public if it doesn't already have an api tag
    object.add_tag YARD::Tags::Tag.new(:api, 'public') unless object.has_tag? :api
  end

  private
  def get_name
    parameters = statement.parameters(false)
    raise YARD::Parser::UndocumentableError, "Expected at least one parameter to 'provide' at #{statement.file}:#{statement.line}." if parameters.empty?
    name = node_as_string(parameters.first)
    raise YARD::Parser::UndocumentableError, "Expected a symbol or string literal for first parameter but found '#{parameters.first.type}' at #{statement.file}:#{statement.line}." unless name
    name
  end

  def register_provider_docstring(object)
    # Walk the tree searching for assignments or calls to desc/doc=
    statement.traverse do |child|
      if child.type == :assign
        ivar = child.jump(:ivar)
        next unless ivar != child && ivar.source == '@doc'
        docstring = node_as_string(child[1])
        log.error "Failed to parse docstring for Puppet provider '#{object.name}' (resource type '#{object.type_name}') near #{child.file}:#{child.line}." and return nil unless docstring
        register_docstring(object, Puppet::Util::Docs.scrub(docstring), nil)
        return nil
      elsif child.is_a?(YARD::Parser::Ruby::MethodCallNode)
        # Look for a call to a dispatch method with a block
        next unless
          child.method_name &&
          (child.method_name.source == 'desc' || child.method_name.source == 'doc=') &&
          child.parameters(false).count == 1

        docstring = node_as_string(child.parameters[0])
        log.error "Failed to parse docstring for Puppet provider '#{object.name}' (resource type '#{object.type_name}') near #{child.file}:#{child.line}." and return nil unless docstring
        register_docstring(object, Puppet::Util::Docs.scrub(docstring), nil)
        return nil
      end
    end
    log.warn "Missing a description for Puppet provider '#{object.name}' (resource type '#{object.type_name}') at #{statement.file}:#{statement.line}."
  end

  def populate_provider_data(object)
    # Traverse the block looking for confines/defaults/commands
    block = statement.block
    return unless block && block.count >= 2
    block[1].children.each do |node|
      next unless node.is_a?(YARD::Parser::Ruby::MethodCallNode) && node.method_name

      method_name = node.method_name.source
      parameters = node.parameters(false)

      if method_name == 'confine'
        # Add a confine to the object
        next unless parameters.count >= 1
        parameters[0].each do |kvp|
          next unless kvp.count == 2
          object.add_confine(node_as_string(kvp[0]) || kvp[0].source, node_as_string(kvp[1]) || kvp[1].source)
        end
      elsif method_name == 'has_feature' || method_name == 'has_features'
        # Add the features to the object
        parameters.each do |parameter|
          object.add_feature(node_as_string(parameter) || parameter.source)
        end
      elsif method_name == 'defaultfor'
        # Add a default to the object
        next unless parameters.count >= 1
        parameters[0].each do |kvp|
          next unless kvp.count == 2
          object.add_default(node_as_string(kvp[0]) || kvp[0].source, node_as_string(kvp[1]) || kvp[1].source)
        end
      elsif method_name == 'commands'
        # Add the commands to the object
        next unless parameters.count >= 1
        parameters[0].each do |kvp|
          next unless kvp.count == 2
          object.add_command(node_as_string(kvp[0]) || kvp[0].source, node_as_string(kvp[1]) || kvp[1].source)
        end
      end
    end
  end
end
