### MSG routines
module MSG
  def sockopen(host, port)
    socket = nil
    status = nil
    timeout = 5.0
    begin
      timeout(5) {
        socket = TCPSocket.open(host, port)
      }
    rescue Timeout::Error
      status = "Timeout"
      return nil
    rescue Errno::ECONNREFUSED
      status = "Refusing connection"
      return nil
    rescue => why
      status = "Error: #{why}"
      return nil
    end
    return socket
  end

  def msg_get(socket, par)
    return nil unless socket
    begin
      socket.send("1 get #{par}\n", 0)
      result = socket.gets
    rescue => why
      status = "Error: #{why}"
      return status
    end
    if (result =~ /ack/)
      answer = result.split('ack')[1].chomp
    else 
      answer = nil
    end
    return answer
  end

  def msg_cmd(socket, command, value)
    return nil unless socket

    begin
      if value
	socket.send("1 #{command} #{value}\n", 0)
      else
	socket.send("1 #{command}\n", 0)
      end
      answer = socket.gets
      
    rescue => why
      status = "Error: #{why}"
      return status
    end

    if (answer =~ /ack/)
      return true
    else 
      return false
    end
  end

  def msg_set(socket, par, value)
    return nil unless socket
    begin
      socket.send("1 set #{par} #{value}\n", 0)
      answer = socket.gets
    rescue => why
      status = "Error: #{why}"
      return status
    end
    if (answer =~ /ack/)
      return true
    else 
      return false
    end
  end
end

