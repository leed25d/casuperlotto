#!/usr/bin/env ruby
require 'yaml'
require 'rubygems'
require 'httpclient'
require 'optparse'
                                                                      
def millions(num)
  res= num % 1000000
  res == 0 ? (num / 1000000) : num.to_f / 1000000
end

def logtime
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

##  grab the superlotto page from the lotto site
url = "http://californialottery.com/Games/SuperLottoPlus"
client = HTTPClient.new
resp = client.get(url)

##  extract current values.  this section is subject to the whims of
##  the calottery site.  Things here can change unpredictably.
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
##  that were last tweeted.  gra bhe config file, too.
cached= YAML::load(File.open('./savedItems.yaml'))
config= YAML::load(File.open('./config.yaml'))

cv= current['CashValue'].downcase;
if (current['CashValue'] !~ /available/i)
  cv= "around $#{millions(current['CashValue'].to_i)} million"
end

current['Message']= "Amanda says: the California Lottery drawing on #{current['DrawDate']} jackpot is about $#{millions(current['Jackpot'].to_i)} million.  Cash value is #{cv}."
changed= (current['Message'] != cached['Message'])

if (changed || OPTIONS[:force])
  require 'twitter'

  ##  Cache the new values.
  File.open("./savedItems.yaml", 'w') { |f| f.puts current.to_yaml } if changed

  if (OPTIONS[:noupdate])
    puts "#{logtime()} --noupdate option was set.  no post to twitter"
  else

    client = Twitter::Client.new(:login => config['login'], :password => config['password'])
    status = client.status(:post, current['Message'])
  end
  puts "#{logtime()} TWEET MSG ==>: '#{current['Message']}'"
else
  ##  log nothing changed
  puts "#{logtime()} No change, cached values are unmodified"
end
