require 'net/http'
module Vertex
  module AdapterOne # driver for Vertexdb 1 (C - version)
        
    # create directory node, example:
    #   GB::Conn.mkdir 'toys'
    def mkdir node
      get node_name(node) + action(:mkdir)
    end

    # removes node (actualy it does not delete node, it deletes link to it, 
    # node deletes only then it have not income links and garbage collector delete it). Example:
    #  GB::Conn.rm 'toys', 'tank'
    def rm node, key
      get node_name(node) + action(:rm, :key => key)
    end

    # get count of nested elements
    #  GB::Conn.rm 'toys' # => return count of elementes
    def size node
      get node_name(node) + action(:size)
    end

    # Creates link node/key to toPath
    #  GB::Conn.link 'toys/tank', 'bob/toys', 
    def link node, to_path, key
      get node_name(node) + action(:link, :key => key, :toPath => to_path)
    end

    # read node content
    #  GB::Conn.read 'users/1', '_name'
    def read node, key
      get node_name(node) + action(:read, :key => key)
    end

    # Writes content to node
    # also can be used to make links, by setting key (without '_' at begining) value equal other node internal id
    #  GB::Conn.read 'users/1', '_name', :set, 'Piter'
    def write node, key, mode, body
      if @in_transaction
        post node_name(node) + action(:write, :key => key, :mode => mode, :value => body.to_s)
      else  
        post node_name(node) + action(:write, :key => key, :mode => mode), body.to_s
      end
    end

    # Selects content
    # support filtering by value of key and number of results
    #  GB::Conn.select 'users/1' # => hash with user properties
    def select node, op = :object, options = {}
      options[:op] = op
      res = get node_name(node) + action(:select, options)
      if res == {'error' => [3, "path does not exist"]}
        return {} if op == :object
        return 0 if op == :count || op == :rm
        return []
      else
        res
      end
    end

    # wrapepr for ?action=backup
    # writes values in memory on disk and make a copy of database file in same folder and with name of current date
    def backup!
      get '/' + action(:backup)
    end
    
    # Finds node by internal id
    #  GB::Conn.find 3452342634
    def find id
      get '/' + action(:find, :id => id)
    end
    
    def increase path, key
      get node_name(path) + action(:increase, :key => key)
    end

    def write_hash(path, key, values)
      post node_name(path) + action(:write_hash, :key => key), JSON.generate(values)
    end
    
    # adds slash in the begining of the string if there is not yet
    # 'items' => '/items'
    # '/items' => '/items'
    def node_name p
      return '' unless p
      path = p.to_s.strip
      path = '/' + path if path[0, 1] != '/'
      path
    end
    
    
    def transaction_start
      @transaction_reqs = []
      @in_transaction = true
    end
    
    def transaction_end
      @in_transaction = false
      reqs = @transaction_reqs.join "\n"
      @transaction_reqs.clear
      post '/?action=transaction', reqs
    end

    private

    # generate action argument
    # action(:read, :key => 'node') => '?action=read&key=node
    def action act, add_args = {}
      '?action=' + act.to_s.strip + args(add_args)
    end

    # {:key => 'position', :arg2 => 'arg_value'} => &key=position&position=arg_value
    def args ha
      return '' if ha.empty?
      '&' + ha.to_a.map {|key, val| key.to_s + '=' + val.to_s.strip }.join('&')
    end
    
    # lazzy, keeping alive connection
    def http_con
      @connect ||= Net::HTTP.start(@host, @port)
      @connect
    end

    def get *args
      if @in_transaction
        @transaction_reqs << args
        return
      end
      @reqs += 1
      res = ''
      puts "-- * " + args.join("|")
      begin
        http_con.get(*args) {|r| res += r }
      rescue; retry; end
      JSON.parse res
    end

    def post *args
      if @in_transaction
        @transaction_reqs << args
        return
      end
      @reqs += 1
      res = ''
      puts "-- * " + args.join("|")
      begin
        http_con.post(*args) {|r| res += r }  
      rescue; retry; end
      JSON.parse res
    end
  end
end