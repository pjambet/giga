# frozen_string_literal: true

# r, w = IO.pipe

server = Ractor.new do
  puts "server starts: #{ inspect }"
  Ractor.yield "foo"
  received = Ractor.receive
  puts "received #{ received }"
end

client = Ractor.new(server) do |srv|
  puts "client starts: #{ inspect }"
  b = srv.take
  puts "Received #{ b }"
  srv.send "Gotcha"
end

# server.send 1
# client.send 2

puts "finalize: #{ client.take }"
server.take

# server = Ractor.new do
#   puts "Server starts: #{self.inspect}"
#   puts "Server sends: ping"
#   Ractor.yield 'ping'                       # The server doesn't know the receiver and sends to whoever interested
#   received = Ractor.receive                 # The server doesn't know the sender and receives from whoever sent
#   puts "Server received: #{received}"
# end

# client = Ractor.new(server) do |srv|        # The server is sent inside client, and available as srv
#   puts "Client starts: #{self.inspect}"
#   received = srv.take                       # The Client takes a message specifically from the server
#   puts "Client received from " \
#        "#{srv.inspect}: #{received}"
#   puts "Client sends to " \
#        "#{srv.inspect}: pong"
#   srv.send 'pong'                           # The client sends a message specifically to the server
# end

# [client, server].each(&:take)               # Wait till they both finish
