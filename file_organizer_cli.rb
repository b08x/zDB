#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'
require 'dotenv'
require 'pastel'
require 'tty-progressbar'

Dotenv.load

require_relative 'lib/models' # The models file we created earlier

class FileOrganizerCLI < Thor
  def initialize(*args)
    super
    @pastel = Pastel.new
  end

  desc "setup", "Setup the database with pgvector"
  def setup
    puts @pastel.blue("Setting up PostgreSQL database with pgvector...")
    
    # Create database if it doesn't exist
    begin
      DB.run("CREATE EXTENSION IF NOT EXISTS vector")
      puts @pastel.green("✓ pgvector extension enabled")
    rescue => e
      puts @pastel.red("Error enabling pgvector: #{e.message}")
      puts @pastel.yellow("Make sure pgvector is installed: sudo apt-get install postgresql-15-pgvector")
      exit 1
    end
    
    # Run migrations from the models file
    require_relative 'lib/models'
    
    puts @pastel.green("✓ Database setup complete!")
  end

  desc "scan PATH", "Scan a directory and add files to the database"
  option :dry_run, type: :boolean, default: false, desc: "Show what would be added without adding"
  def scan(path)
    unless Dir.exist?(path)
      puts @pastel.red("Directory not found: #{path}")
      exit 1
    end
    
    puts @pastel.blue("Scanning #{path}...")
    
    files = Dir.glob(File.join(path, '**', '*')).select { |f| File.file?(f) }
    
    if options[:dry_run]
      puts @pastel.yellow("Dry run mode - no files will be added")
      files.each { |f| puts "  Would add: #{f}" }
      puts @pastel.blue("Total files: #{files.count}")
      return
    end
    
    progress = TTY::ProgressBar.new("Processing [:bar] :percent :current/:total", 
                                    total: files.count)
    
    added = 0
    duplicates = 0
    errors = 0
    
    files.each do |file_path|
      begin
        file = FileOrganizer.add_file(file_path)
        if file
          added += 1
        else
          duplicates += 1
        end
      rescue => e
        errors += 1
        puts @pastel.red("\nError with #{file_path}: #{e.message}")
      ensure
        progress.advance
      end
    end
    
    puts @pastel.green("\n✓ Scan complete!")
    puts "  Added: #{@pastel.green(added)}"
    puts "  Duplicates: #{@pastel.yellow(duplicates)}"
    puts "  Errors: #{@pastel.red(errors)}" if errors > 0
  end

  desc "find_duplicates", "Find and report duplicate files"
  def find_duplicates
    puts @pastel.blue("Finding duplicate files...")
    
    duplicate_hashes = File.find_duplicates
    
    if duplicate_hashes.empty?
      puts @pastel.green("No duplicates found!")
      return
    end
    
    puts @pastel.yellow("Found #{duplicate_hashes.count} sets of duplicates:")
    
    duplicate_hashes.each do |hash|
      files = File.where(sha256_hash: hash).all
      puts "\n#{@pastel.cyan('Hash:')} #{hash[0..16]}..."
      files.each do |file|
        puts "  - #{file.original_path} (#{humanize_bytes(file.file_size)})"
      end
    end
  end

  desc "stats", "Show database statistics"
  def stats
    puts @pastel.blue("File Organizer Statistics")
    puts @pastel.blue("=" * 30)
    
    total_files = File.count
    total_size = File.sum(:file_size) || 0
    file_types = File.group_and_count(:file_type).order(Sequel.desc(:count)).limit(10)
    
    puts "Total files: #{@pastel.green(total_files)}"
    puts "Total size: #{@pastel.green(humanize_bytes(total_size))}"
    puts "\nTop file types:"
    file_types.each do |type|
      puts "  #{type[:file_type].ljust(10)} #{@pastel.cyan(type[:count])}"
    end
    
    duplicates = File.find_duplicates.count
    if duplicates > 0
      puts "\n#{@pastel.yellow("Duplicate sets: #{duplicates}")}"
    end
  end

  desc "process FILE", "Process a single file and extract content"
  def process(file_path)
    unless File.exist?(file_path)
      puts @pastel.red("File not found: #{file_path}")
      exit 1
    end
    
    file = FileOrganizer.add_file(file_path)
    puts @pastel.green("✓ File added to database")
    
    # Extract content based on file type
    case File.extname(file_path).downcase
    when '.rb'
      process_ruby_file(file, file_path)
    when '.md'
      process_markdown_file(file, file_path)
    when '.pdf'
      process_pdf_file(file, file_path)
    else
      puts @pastel.yellow("File type not yet supported for content extraction")
    end
  end

  private

  def humanize_bytes(bytes)
    return "0 B" if bytes == 0
    
    units = %w[B KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.size - 1 if exp >= units.size
    
    "%.2f %s" % [bytes.to_f / (1024 ** exp), units[exp]]
  end

  def process_ruby_file(file, path)
    puts @pastel.blue("Processing Ruby file...")
    
    content = File.read(path)
    file_content = FileContent.create(
      file_id: file.id,
      content: content,
      content_type: 'raw',
      language: 'ruby'
    )
    
    # TODO: Add Ruby parsing with parser gem
    # TODO: Generate embeddings
    
    puts @pastel.green("✓ Ruby file processed")
  end

  def process_markdown_file(file, path)
    puts @pastel.blue("Processing Markdown file...")
    
    content = File.read(path)
    file_content = FileContent.create(
      file_id: file.id,
      content: content,
      content_type: 'raw',
      language: 'markdown'
    )
    
    # TODO: Parse markdown with redcarpet
    # TODO: Generate embeddings
    
    puts @pastel.green("✓ Markdown file processed")
  end

  def process_pdf_file(file, path)
    puts @pastel.blue("Processing PDF file...")
    
    begin
      require 'pdf-reader'
      
      reader = PDF::Reader.new(path)
      text = reader.pages.map(&:text).join("\n")
      
      file_content = FileContent.create(
        file_id: file.id,
        content: text,
        content_type: 'extracted'
      )
      
      # TODO: Generate embeddings
      
      puts @pastel.green("✓ PDF file processed (#{reader.page_count} pages)")
    rescue => e
      puts @pastel.red("Error processing PDF: #{e.message}")
    end
  end
end

FileOrganizerCLI.start(ARGV) if __FILE__ == $0