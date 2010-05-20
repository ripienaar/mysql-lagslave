#!/usr/bin/ruby

# Simple script to monitor lagslave delays with
# nagios based on the age of a heartbeat time stamp 
# and an acceptible range.

require 'rubygems'
require 'mysql'
require 'optparse'

options = {:user => 'nagios',
           :database => 'heartbeat',
           :host => "localhost",
           :password => "",
           :logfile => "/dev/stdout",
           :range => 39600..46800 }#Plus/minus one hour for a default lag of 12 hours.
        
parser = OptionParser.new

parser.separator ""
parser.separator "Monitors a lagged MySQL slave."
parser.separator ""

parser.on('-u', '--user USER', 'User to connect as') do |f|
    options[:user] = f
end

parser.on('-d', '--database DATABASE', 'Heartbeat database') do |f|
    options[:database] = f
end

parser.on('-h', '--host HOST', 'Host to connect to') do |f|
    options[:host] = f
end

parser.on('-p', '--password PASSWORD', 'Password to use') do |f|
    options[:password] = f
end

parser.on('-r', '--range RANGE', 'Set acceptable delay range') do |f|
    options[:range] = f
end

begin
    parser.parse!

    dbh = Mysql.real_connect(options[:host], options[:user], options[:password], options[:database])

    heartbeat = dbh.query("select now() - ts as seconds from heartbeat").fetch_hash
    age = heartbeat["seconds"].to_i

    rng = options[:range].split(':')
    range = Range.new(rng[0].to_i, rng[1].to_i)

    if range.include?(age)
        puts "OK: #{age} seconds behind master|lag=#{age}" 
        exit! 0
    else
        puts "CRITICAL: #{age} seconds behind master|lag=#{age}" 
        exit! 2
    end
rescue Exception => e
    puts "UNKNOWN: #{e}"
    exit 3
end
