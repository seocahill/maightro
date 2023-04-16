# frozen_string_literal: true

# config.ru
require 'bundler'
Bundler.require

require './maightro'

run Sinatra::Application
