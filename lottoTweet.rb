#!/usr/bin/env ruby
require 'optparse'
require 'yaml'
require 'rubygems'
require 'httpclient'

def millions(num)
  res= num % 1000000
  res == 0 ? (num / 1000000) : num.to_f / 1000000
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
  o.define_head "Update twitter with current lottery jackpot"
  o.separator   ""

  o.on("-f", "--force",
       "Force a cache update")          { |OPTIONS[:force]| }
  o.on("-n", "--noupdate",
       "Do not update twitter")         { |OPTIONS[:noupdate]| }

  o.separator ""
  o.on_tail("-h", "--help", "Show this help message.") { puts o; exit }
  o.parse!
end

##  grab the front page from the lotto site
url = "http://californialottery.com/Games/SuperLottoPlus"
client = HTTPClient.new
resp = client.get(url)

##  extract current valuse.  this section is subject to the whims of
##  the calottery site.  Things will change unpredictably.
current={}
current['Jackpot']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblCurJackpot"[^0-9*]*([0-9,]*).*/m, '\1').gsub(/,/, '')
current['CashValue']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLPEstCashValue"[^0-9]*([0-9,]*).*/m, '\1').gsub(/,/, '')
current['DrawDate']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLCJPTDate"[^0-9]*([0-9\/]*).*/m, '\1').gsub(/,/, '')
##puts "current jackpot= #{current['Jackpot']}\ncash value= #{current['CashValue']}\n"

##  grab the values cached from the last run.  These are the values
##  that were last tweeted.
cached= YAML::load(File.open('./savedItems.yaml'))
##puts "cached jackpot= #{cached['Jackpot']}\ncash value= #{cached['CashValue']}\n"

changed=nil
current.keys.each { |k| changed= current["#{k}"] != cached["#{k}"]; break if changed}

if (changed || OPTIONS[:force])
  require 'twitter'

  ##  Cache the new values.
  File.open("./savedItems.yaml", 'w') { |f| f.puts current.to_yaml }

  str= "Amanda says: the next drawing on #{current['DrawDate']} has a projected jackpot of about $#{millions(current['Jackpot'].to_i)} million.  The cash value is around $#{millions(current['CashValue'].to_i)} million."
  if (OPTIONS[:noupdate])
    puts "--noupdate option was set.  no post to twitter"
  else
    client = Twitter::Client.new(:login => 'casuperlotto', :password => 'coltrane')
    status = client.status(:post, str)
  end
  puts "TWEET MSG ==>: '#{str}'"
else
  ##  log nothing changed
  puts "No change, cached values are unmodified"
end
