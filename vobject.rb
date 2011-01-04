require 'vertex-lib/vobject_handler'

module Vertex
  class VObject
    
    attr_reader :data
    
    def initialize data = nil
      @new_record = !@data.nil?
      @data = data
    end
    
    def new_record?
      @new_record
    end
  end
end