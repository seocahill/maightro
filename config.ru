# config.ru
require 'bundler'
Bundler.require

require './maightro.rb'

run Sinatra::Application
