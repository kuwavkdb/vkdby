# frozen_string_literal: true

# require 'pagy/extras/bootstrap'
require 'pagy/extras/overflow'

# Pagy initializer
Pagy::DEFAULT[:items] = 20
Pagy::DEFAULT[:overflow] = :last_page
