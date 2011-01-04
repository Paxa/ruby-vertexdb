# todo: global ids
module GB
  
  def self.Conn
    @connection
  end
  
  def self.Conn= c
    @connection = c
  end
  
  class Model
    class << self
      def location value = nil
        if value
          obj_name = self.to_s
          GB::Manager.register :name => obj_name, :location => value
          @object = GB::Manager.object(obj_name)
          GB::Manager.register_klass obj_name, self
        else
          @object._location
        end
      end
    
      def object value = nil
        @object != '' && @object || nil
      end
      
      def destroy_all!
        Conn.select @object.location, 'rm'
      end
      
      def create data
        puts "-- creating #{self.name} #{data.inspect}"
        new_object = self.new data
        new_object.save
        new_object
      end
      
      def all options = {}
        data = Conn.select @object.location, :values, options
        data.map {|d| data2object d }
      end
      
      def one id
        data = Conn.select @object.location + '/' + id.to_s, :object
        return nil if data == {}
        data2object data
      end
      
      alias :find :one
      
      def find_one options
        data = Conn.select @object.location + '/' , :values, options
        return nil if data == []
        data2object data.first
      end
      
      def delete id
        Conn.rm @object.location, id
      end
      
      def data2object data
        obj = self.new data
        obj.new_record = false
        obj
      end
      
      attr_writer :callbacks

      def callbacks
        @callbacks ||= Hash.new([])
      end
      
      def define_callback action, proc
        callbacks[action] << proc
      end
      
      for action in %w{create save update delete}
        define_method :"before_#{action}" do |&proc|
          define_callback :"before_#{action}", proc
        end
        
        define_method :"after_#{action}" do |&proc|
          define_callback :"after_#{action}", proc
        end
      end
      
      def timestamp *events
        @timestamps ||= []
        @timestamps = events if events.size > 0
        @timestamps
      end
    end
    
    def self.array key
      key = key.to_s
      eval "def #{key}; key_set :#{key}; end"
      eval "def #{key}=(value); key_set(:#{key}).redefine value; end"
    end


    for action in %w{create save update delete}
      class_eval "def before_#{action}(&proc); define_callback :before_#{action}, proc; end;"
      class_eval "def after_#{action}(&proc); define_callback :after_#{action}, proc; end;"
    end
  end
end