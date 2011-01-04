# class for making one-to-many relation
# It's Array based class, that have overwriting methods with preload of content

# USAGE:
# class Post < GModel::Base
#   object 'post'
# 
#   array :tags
#   array :comments
# end

module GB
  class KeySet < Array
    #abbrev   assoc   at   clear   collect   collect!   compact   compact!   concat   dclone   delete   delete_at   delete_if   
    # each   each_index   empty?   eql?   fetch   fill   first   flatten   flatten!   frozen?   hash   include?   index   indexes   
    # indices   initialize_copy   insert   inspect   join   last   length   map   map!   new   nitems   pack   pop   pretty_print   
    # pretty_print_cycle   push   quote   rassoc   reject   reject!   replace   reverse   reverse!   reverse_each   rindex   select   
    # shift   size   slice   slice!   sort   sort!   to_a   to_ary   to_s   transpose   uniq   uniq!   unshift   values_at   zip   |
    
    # lazy loading magic
    for m in %w{map each first last at map select detect collect inspect redefine size length empty? sort present?}
      class_eval "def #{m} *args; preload; super(*args); end"
    end
    
    def initialize parent, key_name, data = nil
      data ||= []
      @parent = parent
      @key_name = key_name
      @loaded = false
      super data
    end
    
    def all
      preload
      self
    end
    
    # overwriting Array '<<' method
    
    define_method :'<<' do |value|
      preload
      raise "Value should be GB::Model object" unless value.kind_of? GB::Model
      if @parent.new_record?
        @parent.after_save {|record| make_link! value }
      else
        make_link! value
      end
      super value
    end
    
    def unlink obj
      obj_id = obj.internal_id
      hash = Conn.select location, :object
      res = 0
      hash.each do |key, int_id|
        if int_id == obj_id
          Conn.rm location, key
          res += 1
        end
      end
      res
    end
    
    def	sorted_by field
      field = field.to_sym
      sort {|a, b| a.method(field).call <=> b.method(field).call }
    end

    def internal_ids
      Conn.select(location).values
    end
    
    def has_link? obj
      if @loaded
        self.detect {|in_set| in_set.object == obj.object && in_set.id == obj.id }
      else
        obj_id = obj.internal_id.to_s
        hash = Conn.select location, :object
         hash
        hash.values.map(&:to_s).include? obj_id
      end
    end
    
    def make_link! value
      new_key = Conn.last_num(location) + 1
      Conn.link value.obj_location, location, new_key
    end
    
    def preload
      return if @loaded || @parent.new_record?
      Conn.mkdir location
      hashes = Conn.select(location, :values)
      raw = hashes.map {|h| GB::Manager.build_object h }
      clear
      push *raw
      @loaded = true
    end
    
    # using for Object.keyset = [other_object]
    def redefine value
      return unless [value].flatten.first.kind_of? GB::Model
      clear
      value.each {|node| obj_push node }
    end
    
    def location
      return nil if @parent.new_record?
      Conn.join @parent.obj_location, @key_name
    end
  end
end