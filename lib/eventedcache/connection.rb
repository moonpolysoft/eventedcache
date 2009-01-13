module EventedCache
  module Connection
    
    def initialize(*args)
      @callbacks = []
      @modes = []
      @protocol = MemcacheProtocol.new
      @never_run = true
    end
    
    #client api
    def set_command(command, key, value, options={}, &cb)
      if !block_given? || options[:noreply]
        options[:noreply] = true
      else
        @callbacks.push cb
        @modes.push :set
      end
      cas = options[:cas] ? " " + options[:cas].to_s : ''
      send_data("#{command} #{key} #{options[:flags] || 0} #{options[:expiry] || 0} #{value.length}#{cas}#{options[:noreply] ? ' noreply' : ''}\r\n#{value}\r\n")
    end
    
    def inc(key, value, options={}, &cb)
      if !block_given? || options[:noreply]
        options[:noreply] = true
      else
        @callbacks.push cb
        @modes.push :inc
      end
      send_data("inc #{key} #{value}#{options[:noreply] ? ' noreply' : ''}\r\n")
    end
    
    def dec(key, value, options={}, &cb)
      if !block_given? || options[:noreply]
        options[:noreply] = true
      else
        @callbacks.push cb
        @modes.push :inc
      end
      send_data("dec #{key} #{value}#{options[:noreply] ? ' noreply' : ''}\r\n")
    end
    
    def get(*keys, &cb)
      @callbacks.push cb
      @modes.push :get
      send_data("get #{keys.join(' ')}\r\n")
    end
    
    def gets(*keys, &cb)
      @callbacks.push cb
      @modes.push :get
      send_data("gets #{keys.join(' ')}\r\n")
    end
    
    #em callbacks
    def post_init
      @connected = true
    end
    
    def receive_data(data)
      @protocol.mode = @modes.shift if @protocol.start_state?
      if @protocol.execute(data)
        #successfully received a full response
        callback = @callbacks.shift
        case @protocol.type
        when :values
          values = @protocol.values
          if values.length == 0
            callback.call(nil)
          elsif values.length == 1
            callback.call(values[0])
          else
            callback.call(values)
          end
        when :stats
          #do something
        when :inc_value
          callback.call(@protocol.inc_value)
        else
          callback.call(@protocol.type)
        end
        @protocol.reset!
      end
    end
    
    def unbind
      @connected = false
    end
  end
end