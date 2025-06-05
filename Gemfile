# frozen_string_literal: true

source 'https://rubygems.org'

# Development tools
gem 'pry'
gem 'rake'
gem 'rubocop'

# Database
gem 'sequel', '~> 5.75'
gem 'pg', '~> 1.5'
gem 'pgvector', '~> 0.2'

# Search and NLP
gem 'bm25f', '~> 0.2.6'
gem 'informers' # For local transformer embeddings

# File processing
gem 'tty-file', '~> 0.10' # For file manipulation utilities
gem 'front_matter_parser', '~> 1.0' # For parsing markdown front matter
gem 'redcarpet', '~> 3.6' # For Markdown parsing
gem 'rouge', '~> 4.2' # For code syntax highlighting and analysis
gem 'parser', '~> 3.3' # For Ruby code AST parsing
gem 'pycall', '~> 1.5' # For Python interop (Docling)

# Utilities
gem 'mime-types', '~> 3.5' # For file type detection
gem 'dotenv', '~> 2.8' # For environment variables
gem 'thor', '~> 1.3' # For CLI commands
gem 'tty-progressbar', '~> 0.18' # For progress bars
gem 'pastel', '~> 0.8' # For colored output
gem 'redis', '~> 5.0' # For Docling results
gem 'httparty', '~> 0.21' # For HTTP requests to Docling service
gem 'rubyzip', '~> 2.3' # For extracting Docling ZIP results

# Testing
group :test do
  gem 'rspec', '~> 3.12'
  gem 'database_cleaner-sequel', '~> 2.0'
  gem 'factory_bot', '~> 6.4'
end