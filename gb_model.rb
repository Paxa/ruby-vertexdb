require "vertex-lib/gb_model_handler"
require "vertex-lib/gb_model_manager"
require "vertex-lib/gb_model_keyset"
require "vertex-lib/gb_model_validators"

module GB
  
  class Model
    
    def define_callback key, block
      @callbacks ||= Hash.new([])
      @callbacks[key] << block
    end
  
    attr_reader :data, :callbacks
    attr_accessor :new_record
  
    def initialize data = {}
      @data = {}
      @key_sets = {}
      
      @new_record = true
      load_from_base = !!(data['_obj_id'] && data['object'])
      
      data.each_pair do |k, v| 
        if load_from_base && k.to_s[0, 1] != '_'
          @data[k.to_sym] = v
        else
          self.send :"#{k.to_s}=", v
        end
      end
      
      #data.each_pair do |k, v|
      #  set_property k.to_s, v, load_from_base
      #end
      
      @data.merge! :object => object.internal_id
      
      @timestamps = self.class.timestamp
        
    end
  
    def update data = {}
      run_callbacks :before_save
      run_callbacks :before_update
      
      return unless validate :save
      return unless validate :update
      
      data.each_pair {|k, v| self.send :"#{k.to_s}=", v }
            
      process_saving!
      run_callbacks :after_save
      run_callbacks :after_update
    end
    
    def save
      was_new_record = @new_record
      run_callbacks :before_save
      run_callbacks :before_create if was_new_record
      
      return false unless validate :save
      return false if was_new_record && !validate(:create)
      
      if @new_record
        @data.merge! :_obj_id => object.get_new_id
        
        @data.merge! :_created_at => Time.now.to_i.to_s if @timestamps.include? :created_at
        
        @new_record = false
      end
      process_saving!
      run_callbacks :after_save
      run_callbacks :after_create if was_new_record
      self
    end
    
    def method_missing method, *args
      if args.size > 0
        set_property method, args.first
      else
        get_property method
      end
    end
    
    def set_property method, value, onload = false, write = false
      
      method = method.to_s[0, method.to_s.size - 1] if method.to_s[-1, 1] == '='
      method = method.to_sym
      und_method = method.to_s[0, 1] == '_' ? method : ('_' + method.to_s).to_sym
      
      if onload || value.kind_of?(GB::Model)
        @data[method] = value
      else
        @data[und_method] = value
      end
    end
    
    def get_property method
      und_method = ('_' + method.to_s).to_sym
      
      if method.to_s[0, 1] == '_' && !@data[method].nil?
        @data[method]
      elsif !@data[und_method].nil?
        @data[und_method]
      elsif !@data[method].nil?
        if @data[method].is_a?(String) || @data[method].is_a?(Fixnum)
          @data[method] = GB::Manager.build_object Conn.find(@data[method])
        end
        @data[method]
      else
        nil
      end
    end
    
    def id
      @data[:_obj_id].to_i
    end
    
    def object
      self.class.object
    end
    
    def key_set key
      @key_sets[key.to_sym] ||= GB::KeySet.new self, key.to_s
      @key_sets[key.to_sym]
    end
    
    alias :new_record? :new_record
    
    def delete!
      run_callbacks :before_delete
      self.class.delete @data[:_obj_id] unless new_record?
      run_callbacks :after_delete
      nil
    end
    
    def created_at
      if @timestamps.include? :created_at
        Time.at @data[:_created_at].to_i
      else
        super
      end
    end
    
    def updated_at
      if @timestamps.include? :created_at
        Time.at @data[:_created_at].to_i
      else
        super
      end
    end
    
    def load_deeper key
      Conn.select Conn.join(obj_location, key), :values
    end
    
    alias :old_inspect :inspect
    
    def inspect
      # drop :object and :_obj_id attributes and split in hash like output
      attributes = data.to_a.map do |pair| 
        next if pair[0] == :object || pair[0] == :_obj_id || pair[0] == :_object
        ":#{pair[0]} => #{pair[1].inspect}"
      end.compact.join ", "
      
      "#<*#{self.class.name}:#{new_record? ? 'NEW' : id} #{attributes}>"
    end
    
    def internal_id
      @internal_id ||= Conn.read object.location, id
      @internal_id
    end
    
    def validate key
      !self.class.validators[key].map do |proc|
        !!proc.call(self)
      end.include?(false)
    end
    
    private
    def convert_data data
      new_data = {}
      data.each_pair do |k, v|
        if v.kind_of? GB::Model
          new_data[k] = v.obj_location
        elsif v.is_a? Hash
          new_data[k] = convert_data v
        else
          new_data[k] = v
        end
      end
      new_data
    end
    
    def obj_key
      obj_id
    end
    
    def obj_location
      return nil if @new_record
      Conn.join(object.location, obj_key)
    end
    
    def process_saving!
      @data.merge! :_updated_at => Time.now.to_i.to_s if @timestamps.include? :updated_at
      new_data = convert_data(@data)
      Conn.write_hash(object.location, self.obj_key, new_data)
      #Conn.multi_write obj_location, new_data
    end
    
    def run_callbacks key
      @callbacks ||= Hash.new([])
      (self.class.callbacks[key] + @callbacks[key]).each do |proc|
        proc.call self
      end
    end
      
  end
end