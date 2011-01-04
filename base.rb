module Vertex
  
  # this is class with some goodies
  
  class Base
    include Vertex::AdapterOne
    
    class << self; attr_accessor :connection; end
    
    attr_accessor :host, :port
    
    def initialize (host, port)
      @host = host
      @port = port
      @reqs = 0
      Vertex::Base.connection = self
    end
    
    # write hash to  specified path
    def multi_write path, content = {}
      path = join *path if path.is_a? Array
      mkdir path
      links = []
      p content
      parser = Proc.new do |scope, hash|
        hash.each do |key, value|

          # run it recursive
          if value.is_a? Hash
            mkdir join(scope, key.to_s)
            parser.call join(scope, key.to_s), value
            next
          end

          # if key starts with '_' - write value, else make links
          if key.to_s[0, 1] == '_' || value.kind_of?(Fixnum)
            write scope, key, 'set', value
          else
            # store links, becouse distanation node may not exists yet
            first = value.to_s[0, 1] == '/' ? value.to_s : join(scope, value.to_s)
            links << [first, join(scope, key.to_s)]
          end
        end
      end

      # run recursive runner
      #transaction_start
      parser.call path, content
      # make links
      links.each {|p| slink p[0], p[1] }
      #transaction_end
    end
    
    # joins the passed paths
    #  GB::Conn.join 'users/1', '../2/girlfriend' # => 'users/2/girlfriend'
    def join *paths
      parts = File.join(*paths.map(&:to_s)).split '/'
      res = []
      parts.each do |part|
        if part == '..'
          res.pop
        else
          res << part
        end
      end
      res.join '/'
    end
    
    # '/path/to/item/name' => ['/path/to]/item', 'name']
    def split_path path
      return ['/', path] unless path.index '/'
      pre_path = path[0, path.rindex('/').to_i]
      key = path[pre_path.size + 1, path.size - pre_path.size - 1]
      [pre_path, key]
    end
    
    # get value of '/_global_id' or set it == 0 if it epsent
    # used in experimental vobject class
    def last_id
      num = read '/', '_global_id'
      unless num
        num = 0
        write '/', '_global_id', :set, num.to_i
      end
      num.to_i
    end
    
    def set_last_id num
      write '/', '_global_id', :set, num.to_i
    end
    
    # remove top level nodes which couses removing all nodes
    def clear!
      select '/', 'rm'
    end
    
    
    # select all keys in location and find the biggest of them
    def last_num location
      keys = select location, :keys
      if keys.is_a? String
        mkdir location
        return 0
      end
      max = 0
      keys.each {|k| max = k.to_i if k.to_i > max}
      max
    end

    # create path of distanation and make link
    def slink node, p2
      link_dir, link_name = split_path p2
      mkdir link_dir unless link_dir == ''
      link node, link_dir, link_name
    end
    
    # wrapper for GB::Conn.rm but this takes one argument
    #  GB::Conn.rm 'users', '1' # equals with
    #  GB::Conn.rm_path 'users/1'
    def rm_path node
      link_dir, link_name = split_path node
      rm link_dir, link_name
    end
    
    def self.c
      connection
    end
    
  end
end