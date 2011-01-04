module GB
  class Model
    class << self
      
      # in model declaration
      # 
      # validate_by :hitriy_checker, 
      #
      # validate options = {}, do |record|
      #   record.something != nil
      # end
      #
      # validate :presence, [:first_name, :last_name]
      # validate :length, [:first_name, :last_name], :min => 4, :max => 16
    
      @@preset_validators = {
        :presence => Proc.new do |value, options|
          value && value != ''
        end,
      
        :length => Proc.new do |value, options|
          size = value.to_s.size
          (options[:min] ? size >= options[:min] : true) &&
          (options[:max] ? size <= options[:max] : true)
        end,
      
        :number => Proc.new do |value|
          # '123' == 123
          # 123 == 123
          # 123 == '123'
          value.to_i.to_s == value.to_s
        end
      }
    
      attr_writer :validators
    
      # can accept symbol, which will mean preset validator
      # or block, what will be run as a validator
      def validate *args, &block
        preset_validator = args.first
        options = args.last.is_a?(Hash) && args.last || {}
      
        if preset_validator.is_a? Symbol
          # bind preset validators
        
          raise "undefined perset validator #{preset_validator}" unless @@preset_validators[preset_validator]
        
          Array(args[1]).each do |field|
            validate_by_proc options do |r|
              @@preset_validators[preset_validator].call r.send(field), options
            end
          end
        else
          validate_by_proc options, block
        end
      end
    
      # calls record method as a validator
      # validate_by :hitriy_checker
      def validate_by method_name, options = {}
        validate_by_proc options, Proc.new do |record|
          record.call method_name
        end
      end
      
      def validators
        @validators ||= {:save => [], :create => [], :update => []}
      end
    
      def validate_by_proc options = {}, &block
        scope = options[:on] || :save
        self.validators[scope] << block
      end
    
    end
  end
end