#!/usr/bin/env ruby
require 'yaml'
require 'rubygems'
require 'httpclient'
require 'optparse'

##  grab the config file
config= YAML::load(File.open('./config.yaml'))


class Float
  def round_to(x)
    (self * 10**x).round.to_f / 10**x
  end
end

class Numeric
  def millions()
    res= self % 1000000
    res == 0 ? (self / 1000000) : ((1.0 * self) / 1000000).round_to(1);
  end
end

def logtime
  ##  return a date like "11SEP2009.2044h26s"
  upcaseMonth= Time.now.strftime("%b").upcase
  Time.now.strftime("%d#{upcaseMonth}%Y.%H%Mh%Ss")
end

# default options
OPTIONS = {
  :force       => false,
  :noupdate    => false,
}

ARGV.options do |o|
  script_name = File.basename($0)

  o.set_summary_indent('  ')
  o.banner =    "Usage: #{script_name} [-fn]"
  o.define_head "    Update twitter with current lottery jackpot totals"
  o.separator   ""

  o.on("-f", "--force",    "Force a cache update")    { |OPTIONS[:force]| }
  o.on("-n", "--noupdate", "Do not update twitter")   { |OPTIONS[:noupdate]| }

  o.separator ""
  o.on_tail("-h", "--help", "Show this help message.") { puts o; exit }
  o.parse!
end

########################################################################
##
##  grab the superlotto page from the lotto site
url = "http://www.calottery.com/games/superlottoplus/"
client = HTTPClient.new
resp = client.get(url)

##  extract current values.  this section is subject to the whims of
##  the calottery site.  Things here can change unpredictably.  If I
##  have to change this even once, I will probably start using the
##  WWW::Mechanize gem instead.
current={}
current['Jackpot']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblCurJackpot"[^0-9*]*([0-9,]*).*/m, '\1').gsub(/,/, '')
unless  (Integer(current['Jackpot']) rescue false)
  puts "#{logtime()} non integer value for Jackpot: #{current['Jackpot']}"
  exit
end

current['CashValue']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLPEstCashValue"[^>]*>\$*([^<]*)<.*/m, '\1').gsub(/,/, '')
unless  (Integer(current['CashValue']) rescue false)
  if (current['CashValue'] !~ /available/i)
      puts "#{logtime()} non integer value for CashValue: #{current['CashValue']}"
      exit
  end
end
current['DrawDate']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLCJPTDate"[^0-9]*([0-9\/]*).*/m, '\1').gsub(/,/, '')

##  grab the values cached from the last run.  These are the values
##  that were last tweeted.
cached= YAML::load(File.open('./savedItems.yaml'))

cv= current['CashValue'].downcase;
if (current['CashValue'] !~ /available/i)
  cv= "around $#{current['CashValue'].to_i.millions} million"
end

current['Message']= "Amanda says: the California Lottery drawing on #{current['DrawDate']} jackpot is about $#{current['Jackpot'].to_i.millions} million.  Cash value is #{cv}."
changed= (current['Message'] != cached['Message'])

if (changed || OPTIONS[:force])
  require 'twitter'

  ##  Cache the new values.
  File.open("./savedItems.yaml", 'w') { |f| f.puts current.to_yaml } if changed

  if (OPTIONS[:noupdate])
    puts "#{logtime()} --noupdate option was set.  no post to twitter"

  else
    begin
      consumer = OAuth::Consumer.new(config['consumer_token'], config['consumer_secret'],
                                     {:site => 'http://twitter.com'})

      request_token = consumer.get_request_token
      response = Net::HTTP.post_form(URI.parse('http://twitter.com/oauth/authorize'),
                                     {"session[username_or_email]" => config['login'],
                                       "session[password]" => config['password'],
                                       "oauth_token" => request_token.token})


      response.body =~ /<div id=\"oauth_pin\">\s*(\d+)\s*</
      pin = $1

      oauth = Twitter::OAuth.new(config['consumer_token'], config['consumer_secret'])
      oauth.authorize_from_request(request_token.token, request_token.secret, pin)
    rescue Exception => authException
      ##  log auth error
      puts "Authorization exceprion" + authException.message
      puts e.backtrace.inspect

    else
      begin
        client = Twitter::Base.new(oauth)
        client.update(current['Message'])
      rescue Exception => postException
        ##  log message post error
        puts "Message post exception" + postException.message
      else
        ##  log success
        puts "#{logtime()} TWEET MSG ==>: '#{current['Message']}'"
      end
    end
  end

else
  ##  log nothing changed
  puts "#{logtime()} No change, cached values are unmodified"
end
