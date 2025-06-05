# frozen_string_literal: true

require 'sequel'
require 'pgvector'
require 'digest'

# Database configuration
DB = Sequel.connect(
  adapter: 'postgres',
  host: ENV['DB_HOST'] || 'localhost',
  port: ENV['DB_PORT'] || 5432,
  database: ENV['DB_NAME'] || 'file_organizer',
  user: ENV['DB_USER'] || 'postgres',
  password: ENV['DB_PASSWORD'] || 'password'
)

# Enable pgvector extension
DB.run('CREATE EXTENSION IF NOT EXISTS vector')

# Add pgvector support to Sequel
Sequel::Model.db.extension :pg_array
Sequel::Model.db.extension :pg_json

# Files table - Core file tracking
DB.create_table?(:files) do
  primary_key :id
  String :original_path, null: false, text: true
  String :centralized_path, text: true
  String :filename, null: false
  String :file_type, null: false # extension
  String :mime_type
  String :sha256_hash, null: false, unique: true
  Integer :file_size
  DateTime :file_modified_at
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
  
  # Status tracking
  String :status, default: 'discovered' # discovered, processing, processed, error
  String :error_message, text: true
  
  # Metadata
  column :metadata, :jsonb
  
  index :sha256_hash
  index :file_type
  index :status
  index :original_path
end

# File contents table - Extracted text and embeddings
DB.create_table?(:file_contents) do
  primary_key :id
  foreign_key :file_id, :files, null: false, on_delete: :cascade
  
  # Content storage
  String :content, text: true
  String :content_type # 'raw', 'extracted', 'processed'
  
  # Embeddings for semantic search
  column :embedding, 'vector(1536)' # Adjust dimension based on your model
  
  # Annotations
  column :annotations, :jsonb
  String :language # For code files
  
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
  
  index :file_id
  index :content_type
end

# Add vector similarity search index
DB.run('CREATE INDEX IF NOT EXISTS file_contents_embedding_idx ON file_contents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)')

# Code annotations table - Specific for code files
DB.create_table?(:code_annotations) do
  primary_key :id
  foreign_key :file_content_id, :file_contents, null: false, on_delete: :cascade
  
  String :annotation_type # 'class', 'method', 'function', 'comment', etc.
  String :name
  Integer :start_line
  Integer :end_line
  String :description, text: true
  column :metadata, :jsonb
  
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  
  index :file_content_id
  index :annotation_type
end

# Tags table - For categorization
DB.create_table?(:tags) do
  primary_key :id
  String :name, null: false, unique: true
  String :category # 'project', 'language', 'topic', etc.
  String :color
  
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  
  index :name
  index :category
end

# Files to tags junction table
DB.create_table?(:file_tags) do
  foreign_key :file_id, :files, null: false, on_delete: :cascade
  foreign_key :tag_id, :tags, null: false, on_delete: :cascade
  
  primary_key [:file_id, :tag_id]
  
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
end

# Duplicate tracking table
DB.create_table?(:file_duplicates) do
  primary_key :id
  String :sha256_hash, null: false
  foreign_key :kept_file_id, :files
  column :duplicate_paths, 'text[]'
  Integer :duplicate_count
  
  DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  
  index :sha256_hash, unique: true
end

# Models
class File < Sequel::Model
  one_to_many :file_contents
  many_to_many :tags, join_table: :file_tags
  
  def before_create
    self.sha256_hash ||= calculate_hash
    super
  end
  
  def before_update
    self.updated_at = Time.now
    super
  end
  
  def calculate_hash
    return nil unless ::File.exist?(original_path)
    Digest::SHA256.file(original_path).hexdigest
  end
  
  def duplicate?
    File.where(sha256_hash: sha256_hash).exclude(id: id).any?
  end
  
  def self.find_duplicates
    select(:sha256_hash)
      .group(:sha256_hash)
      .having { count.function.* > 1 }
      .map(:sha256_hash)
  end
end

class FileContent < Sequel::Model
  many_to_one :file
  one_to_many :code_annotations
  
  # Vector similarity search
  def self.semantic_search(query_embedding, limit: 10)
    DB["SELECT *, embedding <=> ? AS distance FROM file_contents ORDER BY distance LIMIT ?", 
       Sequel.pg_array(query_embedding), limit]
  end
  
  def self.similar_to(file_content, limit: 10)
    return [] unless file_content.embedding
    
    exclude(id: file_content.id)
      .order(Sequel.lit("embedding <=> ?", Sequel.pg_array(file_content.embedding)))
      .limit(limit)
  end
  
  def before_update
    self.updated_at = Time.now
    super
  end
end

class CodeAnnotation < Sequel::Model
  many_to_one :file_content
end

class Tag < Sequel::Model
  many_to_many :files, join_table: :file_tags
end

class FileDuplicate < Sequel::Model
  many_to_one :kept_file, class: :File
  
  def duplicate_files
    File.where(sha256_hash: sha256_hash)
  end
end

# Utility methods
module FileOrganizer
  class << self
    def setup_database
      # Run any additional setup if needed
      puts "Database setup complete with pgvector enabled"
    end
    
    def add_file(path)
      return nil unless ::File.exist?(path)
      
      hash = Digest::SHA256.file(path).hexdigest
      
      # Check if file already exists
      existing = File.first(sha256_hash: hash)
      return existing if existing
      
      File.create(
        original_path: path,
        filename: ::File.basename(path),
        file_type: ::File.extname(path),
        sha256_hash: hash,
        file_size: ::File.size(path),
        file_modified_at: ::File.mtime(path)
      )
    end
    
    def process_directory(directory)
      Dir.glob(::File.join(directory, '**', '*')).each do |path|
        next unless ::File.file?(path)
        
        begin
          add_file(path)
        rescue => e
          puts "Error processing #{path}: #{e.message}"
        end
      end
    end
  end
end