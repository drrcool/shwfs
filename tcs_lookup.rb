#!/usr/bin/ruby

require 'resolv'

def srv_lookup(name)
  srv = "_#{name.downcase.gsub(/_/,"-")}._tcp.mmto.arizona.edu"
  dns =  Resolv::DNS.open
  begin
      resource = dns.getresource(srv, Resolv::DNS::Resource::IN::SRV)
  rescue Resolv::ResolvError
      return nil
  end
  port = resource.port
  host = resource.target.to_s
  return host, port
end

if $0 == __FILE__
   h, p = srv_lookup(ARGV[0])

   print "host = #{h}\n"
   print "port = #{p}\n"
end


