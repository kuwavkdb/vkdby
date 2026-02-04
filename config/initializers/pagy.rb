# frozen_string_literal: true

# require 'pagy/extras/bootstrap'
require 'pagy/extras/overflow'

# Pagy initializer
Pagy::DEFAULT[:limit] = 60
Pagy::DEFAULT[:overflow] = :last_page
