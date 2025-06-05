# frozen_string_literal: true

require 'rake'
require 'dotenv/tasks'

task :environment => :dotenv do
  require_relative 'lib/models'
end

desc "Open a console with the app loaded"
task :console => :environment do
  require 'pry'
  Pry.start
end

namespace :db do
  desc "Run database migrations"
  task :migrate => :environment do
    require 'sequel/extensions/migration'
    
    Sequel::Migrator.run(DB, 'db/migrations')
    puts "Migrations completed"
  end
  
  desc "Rollback database migration"
  task :rollback => :environment do
    require 'sequel/extensions/migration'
    
    Sequel::Migrator.run(DB, 'db/migrations', target: 0)
    puts "Rolled back all migrations"
  end
  
  desc "Create the database"
  task :create do
    require 'dotenv'
    Dotenv.load
    
    db_name = ENV['DB_NAME'] || 'file_organizer'
    system("createdb #{db_name}")
    puts "Database #{db_name} created"
  end
  
  desc "Drop the database"
  task :drop do
    require 'dotenv'
    Dotenv.load
    
    db_name = ENV['DB_NAME'] || 'file_organizer'
    system("dropdb #{db_name}")
    puts "Database #{db_name} dropped"
  end
  
  desc "Reset the database"
  task :reset => [:drop, :create, :migrate] do
    puts "Database reset complete"
  end
end

namespace :scan do
  desc "Scan all configured library directories"
  task :all => :environment do
    directories = {
      'Archive' => ENV['ARCHIVE_PATH'] || '~/Library/Archive',
      'Audio' => ENV['AUDIO_PATH'] || '~/Library/Audio',
      'Documents' => ENV['DOCUMENTS_PATH'] || '~/Library/Documents',
      'Images' => ENV['IMAGES_PATH'] || '~/Library/Images',
      'Source' => ENV['SOURCE_PATH'] || '~/Library/Source',
      'Videos' => ENV['VIDEOS_PATH'] || '~/Library/Videos',
      'Workspace' => ENV['WORKSPACE_PATH'] || '~/Library/Workspace'
    }
    
    directories.each do |name, path|
      expanded_path = File.expand_path(path)
      next unless Dir.exist?(expanded_path)
      
      puts "Scanning #{name} (#{expanded_path})..."
      FileOrganizer.process_directory(expanded_path)
    end
  end
  
  desc "Scan for Ruby files"
  task :ruby => :environment do
    files = File.where(file_type: '.rb').all
    puts "Found #{files.count} Ruby files"
    
    files.each do |file|
      next if FileContent.where(file_id: file.id).any?
      
      begin
        # Process Ruby file
        puts "Processing: #{file.filename}"
        # Add processing logic here
      rescue => e
        puts "Error processing #{file.filename}: #{e.message}"
      end
    end
  end
end

desc "Generate sample data for testing"
task :seed => :environment do
  # Add some sample tags
  tags = [
    { name: 'ruby', category: 'language' },
    { name: 'python', category: 'language' },
    { name: 'javascript', category: 'language' },
    { name: 'ansible', category: 'tool' },
    { name: 'docker', category: 'tool' },
    { name: 'ai', category: 'topic' },
    { name: 'audio', category: 'topic' },
    { name: 'video', category: 'topic' }
  ]
  
  tags.each do |tag_data|
    Tag.find_or_create(tag_data)
  end
  
  puts "Seed data created"
end

desc "Run tests"
task :test do
  system("rspec")
end

task :default => :test