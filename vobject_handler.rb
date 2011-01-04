module Vertex
  class VObject
    class << self
      
      def find global_key
        Vertex::Base.connection.select '/' + global_key, :object
      end
      
      def create data
        new_id = Vertex::Base.connection.last_id + 1
        Vertex::Base.connection.multi_write new_id, data
        Vertex::Base.connection.set_last_id new_id
        Vertex::Base.connection.read('/', new_id).to_i
      end
      
    end
  end
end
      