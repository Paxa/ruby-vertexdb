module GB
  META_LOCATION = '/base_objects'
  
  class Manager
    class << self
          
      def objects
        load_cache
        @obj_cache.map {|o| o['object'] }
      end
    
      def object name
        load_cache
        o = @obj_cache.detect {|a| a['_object_name'] == name.capitalize }
        #p [name, o, @obj_cache]
        o && o['object'] || nil
      end
      
      # GB::Manager.register :name => 'photo', :location => 'photos'
      def register options
        options[:name].capitalize!
        load_cache
        puts "-- registering object #{options[:name]}"
        object_exist = @obj_cache.detect {|a| a['_object_name'] == options[:name] }
        
        if !object_exist
          new_id = Conn.last_num(META_LOCATION).to_i + 1
          data = {
            '_object_name' => options[:name].capitalize,
            '_location' => Conn.node_name(options[:location]),
            '_last_id' => '0',
            '_obj_id' => new_id,
            '_obj_type' => 'class'
          }
          Conn.multi_write [META_LOCATION, new_id], data
          new_data = data.inject({}) {|a, (b, c)| a[b.to_s] = c; a } 
          new_data['internal_id'] = Conn.read META_LOCATION, new_id
          new_data['object'] = ClassObj.new data
          @obj_cache << new_data
        end
        
        Conn.mkdir options[:location]
      end
      
      def delete name
        Conn.select(META_LOCATION, 'pairs').each do |pair|
          if pair[1]['_object_name'] == name
            Conn.rm META_LOCATION, pair[0]
          end
        end
      end
      
      def build_object(data)
        if data['object'].is_a?(Integer) || data['object'].is_a?(String)
          klass = @by_internal_key[data['object'].to_s]
        elsif data['object'].is_a?(Array)
          klass = @klasses[data['object']['_object_name']]
        end
        
        obj = klass[:klass].new(data)
        obj.new_record = false
        obj
      end
      
      # create array of klass objects for creating object by it's klass internal id 
      def register_klass klass_name, klass
        @klasses ||= {}
        @by_internal_key ||= {}
        klass_hash = @obj_cache.detect {|a| a['_object_name'] == klass_name.to_s.capitalize }
        
        klass_key = klass_hash['_obj_id']
        internal_key = klass_hash['internal_id']
        @klasses[klass_name] = {:internal_key => internal_key.to_s, :obj_id => klass_key, :klass => klass, :obj_name => klass_name}
        @by_internal_key[internal_key.to_s] = @klasses[klass_name]
      end
      
      private
      def load_cache
        @obj_cache ||= nil
        if !@obj_cache
          # laod object hashes
          @obj_cache ||= Conn.select META_LOCATION, :values
          # and append to them their internal ids
          Conn.select(META_LOCATION, :object).each do |klass_key, int_id|
            o = @obj_cache.detect {|a| a['_obj_id'].to_i == klass_key.to_i }
            o['object'] = ClassObj.new o
            o['internal_id'] = int_id
          end
        end
        
      end
      
      def reload_cache
        @obj_cache = nil
        load_cache
      end
    end
  end
  
  class ClassObj
        
    def initialize data
      @data = data
    end
    
    def class_location
      META_LOCATION + '/' + @data['_obj_id'].to_s
    end
    
    def last_id
      Conn.read META_LOCATION + '/' + @data['_obj_id'].to_s, '_last_id'
    end
    
    def get_new_id
      Conn.increase META_LOCATION + '/' + @data['_obj_id'].to_s, '_last_id'
    end
    
    def internal_id
      @data["internal_id"]
    end
    
    def update_last_id! new_id
      @data['_last_id'] = new_id
      Conn.write class_location, '_last_id', 'set', new_id
    end
    
    def method_missing method, *args
      method = method.to_s
      method = '_' + method if method[0, 1] != '_'
      if args.size > 0
        @data[method] = args.flatten
      else
        @data[method]
      end
    end
  end
  
end